PROJECT_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

run:
	nvim --cmd "lua vim.opt.runtimepath:prepend('$(PROJECT_ROOT)')"
