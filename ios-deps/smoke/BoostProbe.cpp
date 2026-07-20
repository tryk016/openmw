#include <boost/geometry.hpp>
#include <boost/geometry/index/rtree.hpp>
#include <boost/iostreams/device/mapped_file.hpp>
#include <boost/program_options.hpp>

#include <cstdlib>
#include <iterator>
#include <string>
#include <vector>

int main()
{
    namespace geometry = boost::geometry;
    namespace index = boost::geometry::index;
    namespace options = boost::program_options;

    options::options_description description("OpenMW iOS Boost probe");
    description.add_options()
        ("probe-value", options::value<int>()->default_value(7));
    const char* arguments[] = {
        "OpenMWBoostProbe",
        "--probe-value",
        "11",
    };
    options::variables_map variables;
    options::store(
        options::command_line_parser(3, arguments)
            .options(description)
            .run(),
        variables);
    options::notify(variables);

    using Point = geometry::model::point<float, 2, geometry::cs::cartesian>;
    index::rtree<Point, index::quadratic<4>> tree;
    tree.insert(Point(1.0f, 2.0f));
    std::vector<Point> nearest;
    tree.query(index::nearest(Point(1.0f, 2.0f), 1),
        std::back_inserter(nearest));

    boost::iostreams::mapped_file_source mapped;
    if (std::getenv("OPENMW_IOS_RUN_MAPPED_FILE_PROBE") != nullptr)
        mapped.open("/__openmw_ios_missing_boost_probe__");

    return variables["probe-value"].as<int>() == 11
            && nearest.size() == 1
            && !mapped.is_open()
        ? 0
        : 1;
}
