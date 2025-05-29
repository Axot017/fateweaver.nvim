function add(a, b)
  return a + b
end

function multiply(a, b)
  return a * b
end

function divide(a, b)
  if b == 0 then error("division by zero") end
  return a / b
end

function subtract(a, b)
  return a - b
end
