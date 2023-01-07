extensions[import-a fetch ] ;bitmap]
globals[image scaled largecircle sf]

breed [water waters]
breed [term terms]

water-own [direction]  ;;  1 follows right-hand wall,
                         ;; -1 follows left-hand wall

to loadImage


end

to setup
  clear-all

  set sf 2 ; sf = scalefactor för att kunna ändra storleken på world. FUNKAR INTE!
  ask patches [set pcolor 48.8]  ;Samma färg som bakgrunden på badkaret

    ;;Läs in badkarsbilden från fil
  fetch:url-async "https://raw.githubusercontent.com/Dynasam/netlogoWeb/main/bathtub2_3.png" [
    text ->
    import-a:pcolors text

;Initiera nivån i badkaret. Det är en nivå som ligger omkring hälften av
;badkaret. Den nivån är godtycklig och vald för den visuella upplevelsen.
;Den genererar ca 12000 vattenpunkter. Modellen kalibreras så att detta
;motsvarar 420 ppm. Se Info-fliken hur.
  ask patches with [pcolor = 9.9 and pycor < ((startnivå - 880) / 10)] [
      sprout-water 1 [
        set size 2
        set pen-size 1
        set color blue
        set heading 180
        set shape "square"
      ]
  ]
  ]


  reset-ticks
end


to go

  inflow ;Nytt vatten
  outflow ;Utflödande vatten
  walk ;Förflytta vatten
  reflow ;Omfördela vatten
  remove-water ;Tabort vatten som flödat ut

  if ppm > 900 [stop]
  tick
end

to new-water [x]

let l [52 51 53 50 54 49 55 48 56] ;En lista över vilja pxcor som vatten flödar in ifrån
let lx sublist l 0 x

  foreach lx [ [a] ->
    ;print a
    ask patch (a * sf) (35 * sf) [
      sprout-water 1 [
        set size 2
        set pen-size 1
        facexy a * sf 34 * sf
        set color 108 ;blue
        set direction 1
        set shape "square"
      ]
    ]
  ]

end


to-report period
;  report 2022 + (ticks / (0.5 * 365))
  report 2022 + (ticks / 143.9)
end

to-report ppm
  report (count water) / 30.21
end

;Jag antar en ökning av temperaturen med i genomsnitt 0,86 per 10 ppm
to-report temperature
  report 0.85 * (ppm - 280) / 100
end

to inflow

  ;Öppna kranen varannan ticks och släpp ut motsvarande tillflödes-knappen
  if Tillflöde > 0
  [
    if ticks mod 2 = 0 [  ;Det blir för tätt att generera vatten varje period!
      new-water (Tillflöde / 5)
    ]
  ]
end

to outflow

  ;Öppna luckan varannan ticks och släpp ut motsvarande utflödes-knappen
  if Utflöde > 0 [
    if ticks mod 2 = 0
    [
      empty-tub (Utflöde / 5)
    ]
  ]

end

;Omfördela vattnet med jämna mellanrum så det inte blir luckor
to reflow

  if ticks mod 20 = 0 [
    repeat 10 [move-down-if-possible]
  ]

end

;När vatten flödat ut och slår i botten av avloppet
to remove-water
  ask water [
    if 14.9 = [pcolor] of patch-ahead 1 [die]
  ]
end

;Här tömmer jag kärlet
to empty-tub [x]

  let l [0 -1 1 -2 2 -3 3 -4 4] ;En lista över vilja pxcor som vatten flödar in ifrån
  let nr 0 ;För att påbörja loopen nedan, sedan kommer nästa vatten att läggas på patchen till vänster
  ask up-to-n-of x turtles with [ycor < -50] [  ;Väljer från turtles som är närmare botten
    move-to patch (((item nr l) * sf) - (53 * sf)) (-51 * sf)
    set heading 180
    set color 108
    set nr nr + 1
  ]

  let lx sublist l 0 x

end

;Flytta ned alla water som kan flyttas ned
to move-down-if-possible

  ask water with [heading != 180] [
    let yc ycor
    ;nb är patches nedanför eller vid sidan av vattnet som inte är svart och som
    ;inte har några vatten på sig. Alltså helt tomt vitt under.
    let nb neighbors with [pycor <= yc and (0 != pcolor) and not (any? other turtles-here)]
    let nbempty (count nb) ; (count water-on nb) ;Hur många av grannarna har vatten?
    if nbempty > 0 [move-to one-of nb]
  ]

end


;Jag tillåter två rörelser. Nedåt och åt höger. Det är två händelser som kan förändra
;riktningen. Den ena om det är en vägg, den andra om det är en vatten. Jag måste därför
;testa 1) om det finns en vägg eller en vatten i rutan framför.
to walk  ;; turtle procedure
  ;; turn right if necessary

ask turtles [
  if ycor = 10 [
    set xcor 150 - random 300
    set ycor 0
    set color white
  ]
  let dir whichDirection?

  if dir = 1 [fd 1]
  if dir = 2 [
    set heading 90
    ifelse ycor < 0 [set color blue][set color white] ;yellow]
    fd 1
  ]
  if dir = 3 [
    set heading 270
    ifelse ycor < 0  [set color blue][set color white] ;yellow]
    fd 1
  ]
 ]

  ;Temperaturfärgning är inte tillämpad!
  ;Börja kallt och gå upp till en behaglig blå. Gå sedan över till en mörkare nyans som övergår i rött
  ;ifelse count water < 2000 [set color blue] [ifelse count water < 3000 [set color scale-color blue (count water) 5000 1000] [set color scale-color orange (count water) 2000 5000]]
  ;set color scale-color blue (count water) 6000 -1000
end

;Returnerar TRUE om det är en wall framför, dvs att patch har färgen brun
;to-report wall? [angle]  ;; turtle procedure
to-report wall? ;; turtle procedure
  ;; note that angle may be positive or negative.  if angle is
  ;; positive, the turtle looks right.  if angle is negative,
  ;; the turtle looks left.
;  report brown = [pcolor] of patch-right-and-ahead angle 1
  report brown = [pcolor] of patch-ahead 1
end


;Jag vill tillåta möjligheten att vattnet kan flöda åt antingen vänster eller höger när de slår i "botten".
;Vilket håll ska det välja?
to-report whichDirection?

  let dir1 0 ;rakt fram öppen
  let dir2 0 ;sväng vänster öppen
  let dir3 0 ;sväng höger öppen

;Om vattnet är på väg nedåt har det tre möjliga vägar. Rakt fram=1, Sväng vänster=2, sväng höger=3
  if heading = 180 [
    ;set dir3 3 ;Inte möjligt att svänga höger på väg nedåt  DEN HÄR SKA ÄNDRAS!
    if any? turtles-on patch-ahead 1 or (0 = [pcolor] of patch-ahead 1 and pycor < 0) [set dir1 1] ;stopp framåt Om det inte är stopp nedåt så flytta dit!
    if any? turtles-on patch-left-and-ahead 90 1 or (0 = [pcolor] of patch-left-and-ahead 90 1  and pycor < 0) [set dir2 2] ;stopp åt vänster
    if any? turtles-on patch-right-and-ahead 90 1 or (0 = [pcolor] of patch-right-and-ahead 90 1  and pycor < 0) [set dir3 3] ;stopp åt höger
  ]

;Om vattnet är på väg åt höger så har det också två möjliga vägar. Rakt fram = 1 eller sväng höger = 3
  if heading = 90 [
    set dir2 2 ; inte möjligt att svänga vänster vid horisontell rörelse åt höger
    if any? turtles-on patch-ahead 1 or (0 = [pcolor] of patch-ahead 1  and pycor < 0) [set dir1 1] ;report stopp framåt 1] ;Om det inte är stopp nedåt så flytta dit!
    if any? turtles-on patch-right-and-ahead 90 1 or (0 = [pcolor] of patch-right-and-ahead 90 1  and pycor < 0) [set dir3 3] ;report dirstopp åt höger 3]
  ]

;Om vattnet är på väg åt vänster så har det också två möjliga vägar. Rakt fram = 1 eller sväng vänster = 2
    if heading = 270 [
    set dir3 3 ; inte möjligt att svänga höger vid horisontell rörelse åt vänster
    if any? turtles-on patch-ahead 1 or (0 = [pcolor] of patch-ahead 1  and pycor < 0) [set dir1 1] ;report stopp framåt 1] ;Om det inte är stopp nedåt så flytta dit!
    if any? turtles-on patch-left-and-ahead 90 1 or (0 = [pcolor] of patch-left-and-ahead 90 1  and pycor < 0) [set dir2 2] ;report dirstopp åt vänster 3]
  ]

;Bestäm sedan vilken riktning som ska väljas. Nedåt är prioriterat framför höger och vänster.
  if dir1 = 0 [report 1] ;Rakt fram
  if heading = 180 and dir2 = 0 and dir3 = 3 [report 2] ; sväng vänster
  if heading = 180 and dir3 = 0 and dir2 = 2 [report 3] ; sväng höger
  if heading = 180 and dir3 = 0 and dir2 = 0 [report (random 2) + 2  ] ; sväng slumpmässigt höger eller vänster
  if heading = 90 and dir3 = 0 [report 3] ; sväng höger
  if heading = 270 and dir2 = 0 [report 2] ; sväng vänster
  if dir1 = 1 or dir2 = 2 or dir3 = 3 [report 0] ;stå still

end





;----------------------------------------------------------------------------------------
@#$#@#$#@
GRAPHICS-WINDOW
120
93
619
593
-1
-1
1.22444
1
10
1
1
1
0
1
1
1
-200
200
-200
200
1
1
1
ticks
30.0

BUTTON
35
150
100
183
Kör
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
35
108
99
141
Initiera
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
135
149
227
182
Tillflöde
Tillflöde
0
45
45.0
5
1
Gt
HORIZONTAL

SLIDER
233
149
325
182
Utflöde
Utflöde
0
45
0.0
5
1
Gt
HORIZONTAL

SLIDER
135
110
325
143
Startnivå
Startnivå
0
880
420.0
10
1
ppm
HORIZONTAL

MONITOR
247
406
325
447
År
period
1
1
10

MONITOR
329
407
418
448
Koldioxid, ppm
ppm
1
1
10

MONITOR
422
407
502
448
Temperatur
temperature
1
1
10

TEXTBOX
30
32
626
86
Dynasams badkarsmodell: Välj Startnivå för mängden koldioxid i atmosfären. Nivån 2022 är ca 420 ppm. Välj inflöde och utflöde av koldioxid, mätt i miljoner ton per år. Initiera sedan modellen genom att klicka \"Initiera\" och därefter \"Kör\". Ändra reglagen på inflöde och utflöde för att se hur ppm och temperatur förändras över tid. 
12
0.0
1

@#$#@#$#@
## VAD ÄR DET HÄR?

Detta är en så kallad badkarsmodell över koncentrationen av koldioxid i atmosfären. Genom att variera inflödet och utflödet av vatten så är avsikten att få en intuitiv förståelse under vilka förutsättningar som koncentrationen av koldioxid sänks. Den enkla principen är att utflödet måste vara större än inflödet. 

## HUR FUNGERAR DET

Välj en startnivå på koldioxid. Klicka på initiera och sedan kör. Nivån för 2022 är 420 ppm. Med en högre koncentration så kommer uppvärmningen av jorden att öka. Ökningen av temperaturen antas vara 0,085 grad per 10 ppm ökning i atmosfären. Detta gäller ungefär vid en klimatkänslighet på 3 grader Celsius (https://scied.ucar.edu/interactive/climate-sensitivity-calculator). 

### Vattenpunkter per ppm
Vi styr förändringen genom att påverka tillflödet av ny koldioxid i badkaret och genom att påverka utflödet från badkaret. Inflödet och utflödet gäller antalet Gigaton koldioxid som släpps ut årligen. Omvandlingen sker genom att initiera modellen vid ungefär halva badkaret fyllt. Denna nivå kallas 420 ppm. Utifrån storleken på badkaret vid den nivån som motsvarar det 12689 vattenpunkter. Följaktligen kommer varje ppm att motsvara 12689/420 = 30,212 vattenpunkter. 

Vi tillämpar denna regel för att räkna om antalet vattenpunkter till ppm. 

Fysikalsikt gäller att 1 ppm motsvarar ca 2,1 Gigaton koldioxid. Det innebär att i modellen kommer varje vattenpunkt att motsvara 2,1/30,212 = 0,0695 Gigaton CO2.

### Tidräkningen
Nästa steg i kalibreringen av modellen är påfyllnaden av nytt vatten och hur tidräkningen ska definieras. Simuleringen tillåter årliga flöden på 0 - 45 Gigaton, i intervall om 5 Gigaton. Enligt design, för att låta vattnet rinna på ett visuellt lämpligt sätt, så genereras vattenimpulser varannan tick. Antalet vatten per gång är maximalt 9. Under perioden 2 ticks så kommer det alltså maximalt att kunna flöda in 9 vatten vilket omräknat motsvarar 0,6255 Gigaton per två perioder eller 0,31275 per period. Det innebär i sin tur att vid ett maximalt inflöde om 45 Gigaton på ett år så kommer ett år att motsvaras av  45/0,31275 = 143,9 perioder i modellen. 


## SAKER ATT NOTERA

Även om vi minskar tillflödet av vatten i badkaret som kommer inte nivån att minska så länge som tillflödet är större än utflödet. Det är bara ökningstakten som avtar. 

När tillflödet och utflödet är lika stora så förblir vattennivån stabil. Detta är vad som brukar kallas Netto-noll (Net-Zero). 

Det går att nå netto-noll genom att påverka både tillflödet och utflödet. Fundera lite på vilka olika insatser som skulle påverka respektive flöde. 


## NETLOGO FEATURES

Några särskilda aspekter gällande visualiseringen kan noteras. Det gäller särskilt sättet att flytta runt sköldpaddorna så att badkaret ser någorlunda fyllt ut. Detta är ganska invecklat men det påverkar inte beräkningarna på något sätt. Bland annat tillämpar det Netlogomodellen Wall Following.

En annan sak att notera är inläsningen av badkarsbilden och hur den omvandlas till Netlogo-färger där "extensions" Fetch och Import-a används.

## Credits and References

Programvaran Netlogo:
Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Den specifika implementeringen:
Modellen är programmerad av Fredrik Cullberg Jansson, Dynasam. Den är utvecklad i demonstrationssyfte och kan användas fritt. För mer information vänligen kontakta info@dynasam.com


<!-- 2022 Dynasam -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
random-seed 2
setup
repeat 50 [ go ]
ask turtles [ pen-down ]
repeat 150 [ go ]
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
