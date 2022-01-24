var x [3]int32
x[0] = 1 + 2
x[1] = x[0] - 1
x[2] = x[2 - 1] * 3
println(x[2])

var y [3]float32
y[0] = 1.0 + 2.0
y[1] = y[0] - 1.0
y[2] = y[2 - 1] / 3.0
println(y[2])