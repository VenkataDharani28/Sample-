###############################################################################################
which $SHELL
->/bin/bsh

echo"HI MOM"
-> HI MOM

nano - text editor, #!- shebang
nano himom.sh
-> #!/bin/bsh
echo"HI MOM"

CTR1+X ->Y

ls
->himom.sh

bash himom.sh
->HI MOM

./himom.sh
->permission denied

ls -l
->-rw-r--r-- 1 root root 147 mar 11 20:16 himom.sh

chmod +x himom.sh
ls -l
->-rwxr-xr-x 1 root root 147 mar 11 20:16 himom.sh

./himom.sh
->HI MOM 

#########################################################################################################

nano dharani.sh

->#!/bin/bash
name = "Nani" ----variable
echo"hi $name"
bash dharani.sh
chmod +x dharani.sh


echo"what is your name"
read name -- we give at run time
echo"hi $name have a nice day"



name = $1 ---positional parameter 
color = $2
echo"hi $name have a nice day"
echo"hi $color"

./dharani.sh bey light
->hi bey have a nice day
  hi light


whoami
->root
pwd
->/root
date
->

name = $1 ---positional parameter 
color = $2
user=$(whoami)
date = $(date)
whereami = $(pwd)

echo"hi  $name have a nice day"
echo"hi $color"



echo $RANDOM- >built in variable in linux

when my child can create that variable
then so at that point we created our own variable, system wide,

export -- it will not be per

ls -al

nano .bashrc----export name="jhgf"

then its per exported


echo $((2+3))





