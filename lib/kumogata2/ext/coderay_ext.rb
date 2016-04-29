{
  constant: "\e[1;34m",
  float:    "\e[36m",
  integer:  "\e[36m",
  keyword:  "\e[1;31m",

  key: {
    self:      "\e[1;34m",
    char:      "\e[1;34m",
    delimiter: "\e[1;34m",
  },

  string: {
    self:      "\e[32m",
    modifier:  "\e[1;32m",
    char:      "\e[1;32m",
    delimiter: "\e[1;32m",
    escape:    "\e[1;32m",
  },

  error: "\e[0m",
}.each do |key, value|
  CodeRay::Encoders::Terminal::TOKEN_COLORS[key] = value
end
