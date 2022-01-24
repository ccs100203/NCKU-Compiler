var j int32
var i int32 = 999
for i = 1; i <= 9; i++ {
	for j = 1; j <= 9; j++ {
		print(i)
		print("*")
		print(j)
		print("=")
		print(i*j)
		print("\t")
	}
	print("\n")
}
