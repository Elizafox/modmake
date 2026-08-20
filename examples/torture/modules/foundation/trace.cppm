export module foundation.trace;
import std;

export inline std::string traced(std::string value)
{
    return "[trace] " + value;
}
