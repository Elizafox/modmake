export module app.support;
import std;
import foundation.config;
import foundation.trace;

export inline std::string banner(std::string value)
{
    return traced(value);
}
