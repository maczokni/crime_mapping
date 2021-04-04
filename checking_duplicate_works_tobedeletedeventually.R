myppp <- ppp(c(1,1,0.5,1,3,3,3,3,3,3,1), c(2,2,1,2,5,5,5,5,5,5,4), window=square(6), check=FALSE)
m <- multiplicity(myppp)
plot(X)
dup <- duplicated(X)
print(dup)
um <- uniquemap.ppp(X)
print(um)
Y <- ppp(c(1,1,0.5,1,3,3,3,3,3,3,1), c(2,2,1,2,5,5,5,5,5,5,4),
         window=square(6), check=FALSE, marks = m)
plot(Y)


vals <- values(r1)
hist(vals)
vals <- (vals*1000)/0.3048006096
hist(vals)
r1 <-setValues(r1, vals) #change values in r1 by those we stored in vals
