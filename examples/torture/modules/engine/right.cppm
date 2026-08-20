export module engine:right;
import std;
import :core;
import foundation.trace;

export inline std::string right_branch()
{
    return "right:" + core_value();
}
