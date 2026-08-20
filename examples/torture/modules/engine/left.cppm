export module engine:left;
import std;
import :core;
import app.support;

export inline std::string left_branch()
{
    return banner("left:" + core_value());
}
