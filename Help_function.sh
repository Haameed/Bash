function help()
{
  local s=("$@") b w
  for l in "${s[@]}"; do
    ((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  tput setaf 3
  echo " -${b//?/-}-
| ${b//?/ } |"
  for l in "${s[@]}"; do
    printf '| %s%*s%s |\n' "$(tput setaf 3)" "-$w" "$l" "$(tput setaf 3)"
  done
  echo "| ${b//?/ } |
 -${b//?/-}-"
  tput sgr 0
 
 
 
 
 #### example:
 if [ $# -ne 2 ]
then
help "This script will send your message to phone/phones you provided."  "usage:" "Sample1:" "./sendsms '0912xxxxxxx' 'this is a test message'" "Sample2: multiple phone numbers" "./sendsms '0912xxxxxxx,0935xxxxxxx' 'this is a test message'" "Sample3: multiple line message" "./sendsms '0912xxxxxxx' 'line1\nlin2\line3' "
exit
fi 
