#!/usr/bin/env node

// Dependency-free contract test for docs/ios-port/ROADMAP.md.
// Keep this runnable with the Node.js version preinstalled on GitHub runners.

const fs = require("node:fs");
const path = require("node:path");

const EXPECTED_PHASES = Array.from({ length: 13 }, (_, phase) => phase);
const VALID_STATUSES = new Set(["ukończona", "w toku", "oczekuje"]);

function withoutBold(value) {
    return value.replaceAll("**", "").trim();
}

function parseInteger(value) {
    const plainValue = withoutBold(value);
    return /^\d+$/.test(plainValue) ? Number.parseInt(plainValue, 10) : null;
}

function expectedStatus(completed, total) {
    if (completed === total)
        return "ukończona";
    if (completed === 0)
        return "oczekuje";
    return "w toku";
}

function expectedPercentage(completed, total) {
    return `${((completed / total) * 100).toFixed(1).replace(".", ",")}%`;
}

function findOccurrences(values) {
    const counts = new Map();
    for (const value of values)
        counts.set(value, (counts.get(value) ?? 0) + 1);
    return counts;
}

function maskFencedCode(lines) {
    let fence = null;
    return lines.map((line) => {
        if (fence !== null) {
            const closing = line.match(/^ {0,3}(`+|~+)[ \t]*$/u);
            if (closing
                && closing[1][0] === fence.marker
                && closing[1].length >= fence.length) {
                fence = null;
            }
            return "";
        }

        const opening = line.match(/^ {0,3}(`{3,}|~{3,})(.*)$/u);
        if (!opening)
            return line;

        const marker = opening[1][0];
        // CommonMark does not allow a backtick in the info string of a
        // backtick fence. Such a line is ordinary Markdown, not an opener.
        if (marker === "`" && opening[2].includes("`"))
            return line;

        fence = { marker, length: opening[1].length };
        return "";
    });
}

function validateRoadmap(contents) {
    const lines = contents.replaceAll("\r\n", "\n").split("\n");
    const visibleLines = maskFencedCode(lines);
    const errors = [];

    const phaseHeadings = [];
    const h2Headings = [];
    for (const [index, line] of visibleLines.entries()) {
        if (/^ {0,3}##(?:[ \t]+|$)/u.test(line))
            h2Headings.push(index);
        const match = line.match(/^ {0,3}##[ \t]+Faza\s+(\d+)\s+[—-]/u);
        if (match)
            phaseHeadings.push({ phase: Number.parseInt(match[1], 10), line: index });
    }

    const headingCounts = findOccurrences(phaseHeadings.map(({ phase }) => phase));
    for (const phase of EXPECTED_PHASES) {
        const count = headingCounts.get(phase) ?? 0;
        if (count === 0)
            errors.push(`Brak sekcji \"Faza ${phase}\".`);
        else if (count > 1)
            errors.push(`Sekcja \"Faza ${phase}\" występuje ${count} razy.`);
    }
    for (const phase of [...headingCounts.keys()].filter((value) => !EXPECTED_PHASES.includes(value)))
        errors.push(`Nieoczekiwana sekcja \"Faza ${phase}\".`);

    const phaseCounts = new Map();
    for (const heading of phaseHeadings) {
        if ((headingCounts.get(heading.phase) ?? 0) !== 1 || !EXPECTED_PHASES.includes(heading.phase))
            continue;

        const nextH2 = h2Headings.find((line) => line > heading.line);
        const end = nextH2 ?? visibleLines.length;
        let completed = 0;
        let total = 0;
        for (const line of visibleLines.slice(heading.line + 1, end)) {
            const checkbox = line.match(/^\s*-\s+\[([ xX])\]\s+/u);
            if (!checkbox)
                continue;
            total += 1;
            if (checkbox[1].toLowerCase() === "x")
                completed += 1;
        }
        if (total === 0)
            errors.push(`Sekcja \"Faza ${heading.phase}\" nie zawiera checkboxów.`);
        phaseCounts.set(heading.phase, { completed, total });
    }

    const progressHeading = visibleLines.findIndex((line) => line.trim() === "## Postęp");
    let progressEnd = -1;
    if (progressHeading === -1) {
        errors.push("Brak sekcji tabeli \"Postęp\".");
    } else {
        progressEnd = h2Headings.find((line) => line > progressHeading) ?? visibleLines.length;
    }

    const tableRows = [];
    let totalRow = null;
    if (progressHeading !== -1) {
        for (const [offset, line] of visibleLines.slice(progressHeading + 1, progressEnd).entries()) {
            if (!line.trim().startsWith("|"))
                continue;
            const cells = line.split("|").slice(1, -1).map((cell) => cell.trim());
            if (cells.length !== 4)
                continue;

            const label = withoutBold(cells[0]);
            if (/^\d+$/u.test(label)) {
                tableRows.push({
                    phase: Number.parseInt(label, 10),
                    completed: parseInteger(cells[1]),
                    total: parseInteger(cells[2]),
                    status: withoutBold(cells[3]),
                    line: progressHeading + offset + 2,
                });
            } else if (label === "Razem") {
                if (totalRow !== null)
                    errors.push("Wiersz \"Razem\" występuje więcej niż raz.");
                totalRow = {
                    completed: parseInteger(cells[1]),
                    total: parseInteger(cells[2]),
                    percentage: withoutBold(cells[3]),
                    line: progressHeading + offset + 2,
                };
            }
        }
    }

    const tableCounts = findOccurrences(tableRows.map(({ phase }) => phase));
    for (const phase of EXPECTED_PHASES) {
        const count = tableCounts.get(phase) ?? 0;
        if (count === 0)
            errors.push(`Brak fazy ${phase} w tabeli postępu.`);
        else if (count > 1)
            errors.push(`Faza ${phase} występuje ${count} razy w tabeli postępu.`);
    }
    for (const phase of [...tableCounts.keys()].filter((value) => !EXPECTED_PHASES.includes(value)))
        errors.push(`Nieoczekiwana faza ${phase} w tabeli postępu.`);

    for (const row of tableRows) {
        if ((tableCounts.get(row.phase) ?? 0) !== 1 || !EXPECTED_PHASES.includes(row.phase))
            continue;
        if (row.completed === null || row.total === null) {
            errors.push(`Faza ${row.phase} ma niepoprawny licznik w tabeli (wiersz ${row.line}).`);
            continue;
        }
        if (!VALID_STATUSES.has(row.status)) {
            errors.push(
                `Faza ${row.phase} ma nieznany status \"${row.status}\"; `
                + "dozwolone: ukończona, w toku, oczekuje."
            );
        }

        const actual = phaseCounts.get(row.phase);
        if (!actual)
            continue;
        if (row.completed !== actual.completed || row.total !== actual.total) {
            errors.push(
                `Faza ${row.phase}: tabela podaje ${row.completed}/${row.total}, `
                + `checkboxy dają ${actual.completed}/${actual.total}.`
            );
        }

        const status = expectedStatus(actual.completed, actual.total);
        if (row.status !== status)
            errors.push(`Faza ${row.phase}: status \"${row.status}\", oczekiwano \"${status}\".`);
    }

    const summed = EXPECTED_PHASES.reduce(
        (result, phase) => {
            const counts = phaseCounts.get(phase);
            if (counts) {
                result.completed += counts.completed;
                result.total += counts.total;
            }
            return result;
        },
        { completed: 0, total: 0 }
    );

    if (totalRow === null) {
        errors.push("Brak wiersza \"Razem\" w tabeli postępu.");
    } else if (totalRow.completed === null || totalRow.total === null) {
        errors.push(`Wiersz \"Razem\" ma niepoprawny licznik (wiersz ${totalRow.line}).`);
    } else if (phaseCounts.size === EXPECTED_PHASES.length) {
        if (totalRow.completed !== summed.completed || totalRow.total !== summed.total) {
            errors.push(
                `Razem: tabela podaje ${totalRow.completed}/${totalRow.total}, `
                + `checkboxy dają ${summed.completed}/${summed.total}.`
            );
        }
        const percentage = expectedPercentage(summed.completed, summed.total);
        if (totalRow.percentage !== percentage) {
            errors.push(
                `Razem: procent \"${totalRow.percentage}\", oczekiwano \"${percentage}\" `
                + "(jedno miejsce po przecinku)."
            );
        }
    }

    return { errors, phaseCounts, summed };
}

function assertInvalid(name, contents, expectedMessage) {
    const { errors } = validateRoadmap(contents);
    if (!errors.some((error) => error.includes(expectedMessage))) {
        throw new Error(
            `Self-test \"${name}\" nie wykrył \"${expectedMessage}\". `
            + `Otrzymane błędy: ${JSON.stringify(errors)}`
        );
    }
}

function assertValid(name, contents) {
    const { errors } = validateRoadmap(contents);
    if (errors.length > 0)
        throw new Error(`Self-test \"${name}\" odrzucił poprawną fixture:\n${errors.join("\n")}`);
}

function replaceOnce(contents, pattern, replacement, name) {
    if (!pattern.test(contents))
        throw new Error(`Self-test \"${name}\" nie znalazł wzorca mutacji.`);
    return contents.replace(pattern, replacement);
}

function runSelfTests(contents) {
    const baseline = validateRoadmap(contents);
    if (baseline.errors.length > 0)
        throw new Error(`Roadmapa bazowa self-testów jest niepoprawna:\n${baseline.errors.join("\n")}`);

    const phaseZero = baseline.phaseCounts.get(0);
    const phaseZeroStatus = expectedStatus(phaseZero.completed, phaseZero.total);
    const wrongPhaseZeroStatus = phaseZeroStatus === "ukończona" ? "w toku" : "ukończona";

    assertInvalid(
        "brak sekcji",
        replaceOnce(contents, /^## Faza 12[^\n]*$/mu, "## Usunięta faza 12", "brak sekcji"),
        "Brak sekcji \"Faza 12\""
    );
    assertInvalid(
        "duplikat sekcji",
        `${contents}\n## Faza 0 — duplikat\n- [ ] test\n`,
        "Sekcja \"Faza 0\" występuje 2 razy"
    );
    assertInvalid(
        "błędny licznik",
        replaceOnce(
            contents,
            new RegExp(`^\\| 0 \\| ${phaseZero.completed} \\| ${phaseZero.total} \\|`, "mu"),
            `| 0 | ${phaseZero.completed - 1} | ${phaseZero.total} |`,
            "błędny licznik"
        ),
        "checkboxy dają"
    );
    assertInvalid(
        "błędny status",
        replaceOnce(
            contents,
            new RegExp(
                `^\\| 0 \\| ${phaseZero.completed} \\| ${phaseZero.total} \\| [^|]+\\|$`,
                "mu"
            ),
            `| 0 | ${phaseZero.completed} | ${phaseZero.total} | ${wrongPhaseZeroStatus} |`,
            "błędny status"
        ),
        `oczekiwano \"${phaseZeroStatus}\"`
    );
    assertInvalid(
        "błędny procent",
        replaceOnce(contents, /\| \*\*Razem\*\* \|([^\n]*)\| \*\*[0-9]+,[0-9]%\*\* \|/u,
            "| **Razem** |$1| **0.0%** |", "błędny procent"),
        "jedno miejsce po przecinku"
    );
    assertInvalid(
        "brak fazy w tabeli",
        replaceOnce(contents, /^\| 12 \|[^\n]*\n/mu, "", "brak fazy w tabeli"),
        "Brak fazy 12 w tabeli postępu"
    );
    assertInvalid(
        "duplikat fazy w tabeli",
        replaceOnce(contents, /^(\| 0 \|[^\n]*\n)/mu, "$1$1", "duplikat fazy w tabeli"),
        "Faza 0 występuje 2 razy w tabeli postępu"
    );

    assertValid(
        "H2 po fazie 12",
        `${contents}\n## Dodatek\n\n- [x] Checkbox dodatku poza fazami.\n`
    );
    assertValid(
        "H2 między fazami",
        replaceOnce(
            contents,
            /^## Faza 1/mu,
            "## Dodatek między fazami\n\n- [x] Checkbox dodatku poza fazami.\n\n## Faza 1",
            "H2 między fazami"
        )
    );
    assertValid(
        "checkbox w backtick fence",
        replaceOnce(
            contents,
            /^## Faza 1/mu,
            "```markdown\n- [x] To jest przykład, nie zadanie.\n```\n\n## Faza 1",
            "checkbox w backtick fence"
        )
    );
    assertValid(
        "fałszywa faza w tilde fence",
        replaceOnce(
            contents,
            /^## Faza 1/mu,
            "~~~markdown\n## Faza 7 — przykład\n- [ ] To jest przykład.\n~~~~\n\n## Faza 1",
            "fałszywa faza w tilde fence"
        )
    );
    assertValid(
        "fence zamyka tylko zgodny delimiter",
        replaceOnce(
            contents,
            /^## Faza 1/mu,
            "````markdown\n```\n~~~\n## Faza 8 — przykład\n- [x] To jest przykład.\n````\n\n## Faza 1",
            "fence zamyka tylko zgodny delimiter"
        )
    );

    if (expectedPercentage(1, 6) !== "16,7%")
        throw new Error("Self-test zaokrąglenia procentu nie dał 16,7% dla 1/6.");

    console.log(
        "PASS: self-testy kontraktu roadmapy wykryły 6 klas błędów, "
        + "sprawdziły 5 regresji zakresu/fence i zaokrąglenie."
    );
}

function printValidationResult(file, result) {
    if (result.errors.length > 0) {
        console.error(`FAIL: ${file}`);
        for (const error of result.errors)
            console.error(`- ${error}`);
        process.exitCode = 1;
        return;
    }
    console.log(
        `PASS: ${file}: fazy 0–12, ${result.summed.completed}/${result.summed.total} `
        + `(${expectedPercentage(result.summed.completed, result.summed.total)}).`
    );
}

function main() {
    const args = process.argv.slice(2);
    const selfTest = args.includes("--self-test");
    const positional = args.filter((argument) => argument !== "--self-test");
    if (positional.length > 1) {
        console.error("Użycie: node CI/ios/test-roadmap-contract.js [--self-test] [ROADMAP.md]");
        process.exitCode = 2;
        return;
    }

    const file = positional[0] ?? path.join("docs", "ios-port", "ROADMAP.md");
    const contents = fs.readFileSync(file, "utf8");
    if (selfTest)
        runSelfTests(contents);
    printValidationResult(file, validateRoadmap(contents));
}

if (require.main === module)
    main();

module.exports = { expectedPercentage, expectedStatus, maskFencedCode, validateRoadmap };
