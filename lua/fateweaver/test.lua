function add(a, b)
  return a + b
end

function subtract(a, b)
  if type(b) == "number" then
    return a - b
  else
    error("Invalid argument: second parameter must be a number")
  end
end

function multiply(a, b)
  return a * b
end
