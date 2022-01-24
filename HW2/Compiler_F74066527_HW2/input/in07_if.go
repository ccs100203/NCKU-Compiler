var x int32 = 0
if x == 0 { /* if */
	println("Hello")
	/* print
	a Hello with
	newline */
}

if x != 0 { /* if else */
	var y float32 = 3.14
	print("If x != ")
	println(0)
	println(y)
} else {
	var z float32 = 6.6
	print("If x == ")
	println(0)
	println(z)
}

var y int32 = 1
if x != 0 { // else if
	var y float32 = 3.14
	print("If x != ")
	println(0)
	println(y)
} else if y != 0 {
	var z float32 = 6.6
	print("If y != ")
	println(0)
	println(z)
}

if x != 0 { // long if else if
	var y float32 = 3.14
	print("If x != ")
	println(0)
	println(y)
} else if y != 0 {
	var z float32 = 6.6
	print("If y != ")
	println(0)
	println(z)
} else if y == 0 {
	var zz float32 = 6.66
	print("If y == ")
	println(0)
	println(zz)
} else {
	println("else")
}