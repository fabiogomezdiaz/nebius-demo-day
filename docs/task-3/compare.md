# Task 3 — original vs LoRA

n=10, temperature=0, max_tokens=128. Held-out Dolly `train[1500:]`.

## TL;DR

- Job 73 was 4 SFT steps. Answers stay close; no clear LoRA win.
- Original faster on 9/10 (mean 1.015s vs 1.335s).
- Token cap 128 hit on 6/10 original, 7/10 LoRA.

| # | Id | Orig (s) | LoRA (s) | Orig | LoRA |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `dolly-1500` | 1.211644 | 1.605619 | Popular young adult (YA) books often span a wide range of genres and themes, reflecting the diverse interests and experiences of young readers. Here are some po… | There are many popular young adult (YA) books across various genres that have captured the hearts and imaginations of readers around the world. Here are some no… |
| 2 | `dolly-1502` | 0.400695 | 0.461905 | - The Thanksgiving Song - The Chanukah Song | - The Thanksgiving Song - The Chanukah Song |
| 3 | `dolly-1503` | 1.128489 | 1.600172 | The highest score possible in a single game of ten-pin bowling is 300. This score is known as a perfect game and requires the bowler to achieve a strike (knocki… | The highest score possible in a single game of ten-pin bowling is 300. This perfect score is achieved when a player bowls three strikes in a row in the first th… |
| 4 | `dolly-1504` | 1.199383 | 1.619642 | As of 2023, the top manufacturers of electric vehicles (EVs) sold in the United States are:  1. **Tesla**: Tesla is currently the leader in the U.S. EV market. … | As of 2023, the top five manufacturers of electric vehicles (EVs) sold in the United States are:  1. **Tesla**: Tesla is currently the leader in the U.S. EV mar… |
| 5 | `dolly-1505` | 1.191900 | 1.610165 | The number of miles driven per year can vary significantly depending on factors such as location, lifestyle, and transportation habits. However, according to da… | The number of miles driven per year can vary significantly depending on factors such as location, lifestyle, and personal transportation habits. However, accord… |
| 6 | `dolly-1506` | 1.195346 | 1.591302 | Yes, Alaska does have a professional sports team. The Anchorage Aces played in the ECHL (East Coast Hockey League) from 2013 to 2019, based in Anchorage, Alaska… | Alaska does not currently have any professional sports teams in the major North American leagues (NFL, NBA, NHL, MLB). However, it does have some professional t… |
| 7 | `dolly-1507` | 1.197256 | 1.616882 | Certainly! Italy is home to several unique and historic horse breeds. Here's a list of some notable Italian horse breeds:  1. **Malerese Horse** - Originating f… | Italy is home to several unique and historic horse breeds, each with its own characteristics and history. Here's a list of some notable Italian horse breeds:  1… |
| 8 | `dolly-1508` | 1.193750 | 1.620980 | Grizzly bears (Ursus arctos horribilis) were historically found in parts of California, but they are now considered extinct in the state. The last known grizzly… | Grizzly bears (Ursus arctos horribilis) were once found throughout much of western North America, including parts of California. However, they have been extirpa… |
| 9 | `dolly-1509` | 0.630768 | 0.606653 | President Donald Trump appointed a total of 54 federal appellate judges and 3 U.S. Supreme Court justices during his presidency. This information is accurate ba… | President Donald Trump appointed a total of 54 federal appellate judges and 3 U.S. Supreme Court justices during his presidency. |
| 10 | `dolly-1510` | 0.801436 | 1.020235 | The first human to walk on the moon was Neil Armstrong, an American astronaut. He took his historic step on July 20, 1969, as part of the Apollo 11 mission. His… | The first human to walk on the moon was Neil Armstrong, an American astronaut. He took his historic step on July 20, 1969, as part of NASA's Apollo 11 mission. … |

