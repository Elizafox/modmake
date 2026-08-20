export module data.model;
import std;
import foundation.config;

export inline std::string model_value()
{
    return "40" + config_suffix();
}
