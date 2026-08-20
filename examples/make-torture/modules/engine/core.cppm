module engine:core;
import std;
import data.model;
import math.calc;

inline std::string core_value()
{
    return calculated() + model_value().substr(2);
}
