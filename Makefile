
doc:
	#mandoc -T html yeti.n > yeti.html
	pandoc yeti.n --from man --css mini.css -s --metadata title="yeti 0.4 documentation" -o yeti-out.html
	pandoc ylex.n --from man --css mini.css -s --metadata title="yeti 0.4 documentation" -o ylex-out.html	
	htmlark yeti-out.html -o yeti.html
	htmlark ylex-out.html -o ylex.html	
	#mandoc -T html style==file:///home/groth/workspace/github/yeti/mini.css ylex.n > ylex.html
