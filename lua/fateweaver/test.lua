function add(value_a, value_b)
  return value_a + value_b
end

function subtract(value_a, value_b)
  return value_a - value_b
end

function divide(value_a, value_b)
  if value_b == 0 then error("Division by zero") end
  return value_a / value_b
end

function multiply(value_a, value_b)
  return value_a * value_b
end
