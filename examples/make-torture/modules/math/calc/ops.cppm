export module math.calc:ops;
import std;
import foundation.config;

export inline std::string add_two()
{
    return "2" + config_suffix();
}
