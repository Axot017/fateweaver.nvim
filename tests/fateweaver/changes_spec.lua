local new_set = MiniTest.new_set

local T = new_set({
  hooks = {
    pre_case = function()
    end,

    post_case = function()
    end,
  },
})

T['save_change'] = function()
end

return T
