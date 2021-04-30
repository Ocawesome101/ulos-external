-- carddock --

local component = require("component")

for k in component.list("carddock") do
  component.invoke(k, "bindComponent")
end
