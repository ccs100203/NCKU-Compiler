var i int32
for i = 0; i < 10; i++ {
	println(i)
}

{
	var x [3]int32
	x[0] = 1 + 2
	x[1] = x[0] - 1
	x[2] = x[1] / 3
	println(x[2])
	println(3 - 4 * (+5 + -8) - 10 / 7 > -4 % 3 || !true && !!false)

	var yy [3]float32
	yy[0] = 1.1 + 2.1
	println(int32(yy[0]))
}

var x int32 = 0
x += 2
for x > 0 {
	println(x)
	x--
	if x != 0 {
		var y float32 = 3.14
		println(int32(y + 1.0))
		print("If x != ")
		println(0)
		println(y)
		/* print
		a string and y with
		newline */
	} else {
		var z float32 = 6.6
		print("If x == ")
		println(0)
		println(z)
	}
	var j int32
	for j = 1; j <= 3; j++ {
		print(x)
		print("*")
		print(j)
		print("=")
		print(x*j)
		print("\t")
	}
}