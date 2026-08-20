export module math.calc;
export import :ops;
export import :format;
import std;

export inline std::string calculated()
{
    return format_number("4" + add_two().substr(0, 1));
}
