
demo atm:
```shell
➜  typed-fsm-zig git:(master) ✗ zig build atm
current state: ready
insert or exit: insert
current state: cardInserted
input pin: 1234
The pin correct, goto session!
current state: session
getAmount or disponse or eject: getAmount
amount: 10000
current state: session
getAmount or disponse or eject: 100
disponse: 100
new amount: 9900
current state: session
getAmount or disponse or eject: 100
disponse: 100
new amount: 9800
current state: session
getAmount or disponse or eject: 100
disponse: 100
new amount: 9700
current state: session
getAmount or disponse or eject: eject
eject card
current state: ready
insert or exit: exit
Exit ATM!
```
