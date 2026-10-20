Output demo/demo.gif

Require nvim

Set Shell "bash"
Set FontSize 16
Set Width 1100
Set Height 680
Set Padding 14
Set Theme { "name": "demo", "background": "#141415", "foreground": "#cdcdcd" }
Set TypingSpeed 70ms

Hide
Type "export DEMO=$PWD && bash demo/setup.sh && cd /tmp/agentreview-demo" Enter
Type "alias nvim='nvim -u $DEMO/demo/init.lua'" Enter
Type "PS1='$ ' && clear" Enter
Sleep 1s
Show

Type "nvim -c AgentReview"
Sleep 600ms
Enter
Sleep 2s

Type "]h"
Sleep 900ms
Type "]h"
Sleep 900ms
Type "[h"
Sleep 1200ms

Type "/retries = 3"
Enter
Sleep 600ms
Type "Vj"
Sleep 600ms
Type "c"
Sleep 600ms
Type "why 5? make it configurable"
Sleep 500ms
Enter
Sleep 1500ms

Type "/timeout = 10"
Enter
Sleep 600ms
Type "viw"
Sleep 600ms
Type "c"
Sleep 600ms
Type "name this constant"
Sleep 500ms
Enter
Sleep 1800ms

Type "g?"
Sleep 2500ms
Type "q"
Sleep 800ms

Type "]f"
Sleep 1200ms

Type ":AgentReviewSend"
Sleep 500ms
Enter
Sleep 1200ms
Type ":echo getreg('+')"
Sleep 500ms
Enter
Sleep 3s

Type ":qa!"
Enter
Sleep 800ms
