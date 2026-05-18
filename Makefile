run:
	# Add current directory to 'runtimepath' with --cmd
	nvim --cmd "let &rtp.=','.getcwd()"
