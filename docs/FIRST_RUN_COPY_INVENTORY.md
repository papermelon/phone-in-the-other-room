# First-run copy inventory

User-facing strings for the universal first-run journey. Sources stay local. None of this
diagnoses a sleep condition or promises better sleep.

| Screen | State | Copy | Source IDs | Rationale |
|---|---|---|---|---|
| Welcome · Counting Sheep | Narrative 1 | Give the phone a resting place. Counting Sheep helps make room around sleep by giving the phone a resting place in another room. | — | Names the product without workshops or medical claims. |
| Welcome · Wind Down | Narrative 2 | Wind Down holds the whole night. Wind Down spans quiet before bed, overnight phone separation, and quiet after waking. | — | Explains the ritual span. |
| Welcome · Phone Away | Narrative 3 | Phone Away is a shorter stretch. Optional app shielding can make selected apps harder to reopen while the phone rests. | — | Distinguishes Phone Away; shielding is optional. |
| Welcome · Ollie | Narrative 4 | Ollie keeps watch and searches for missing sheep while you follow through. | — | Introduces the mascot without urgency. |
| Questionnaire | All questions | A few questions, kept on this iPhone. These answers help choose a starting point. They do not diagnose a sleep condition or name a disorder. | — | On-device; non-clinical. |
| Recommendation | After answers | Your Wind Down starting point. Based on what you told us, these ideas may be useful places to begin. | Mapped `WindDownGuidanceLibrary` IDs | Honest mapping, sourced ideas, skip does not undo a completed questionnaire. |
| Gift announcement | Questionnaire completed | Moonlit Coat was added to your wardrobe. Keep my current outfit / Wear Moonlit Coat. | Catalogue wearable ID | Questionnaire owns the gift; wearing it is an explicit choice. |
| Gift announcement | Questionnaire skipped | You can choose a starting point later. Wind Down still works. | — | Skip is first-class. |
| Practice offer | Guide | This creates a real Nights record. It is not a protected night, and it does not add to the usual Phone Away search meter. | — | Honest about rewards and meters. |
| Practice reward | New sheep granted | Ollie brought a second sheep home. | `pippin` | Only when this completion minted the sheep. |
| Practice reward | Sheep already granted | Practice is in Nights. Your welcome-gift sheep is still on the Farm. | — | Replay must not pretend a second Pippin arrived. |
| Farm chapter offer | First user-initiated Farm visit | Want the four-tip Farm tour? Meet the flock, The Barn, the wardrobe, and Ollie’s Search. Show me / Explore on my own. | — | Farm guidance is opt-in after the Home exploration pause. |
| Wardrobe | Gift owned | Welcome gift · Owned. Wear / Take off. | Wearable item ID | The gift is visible without a wool price or progression unlock. |
| Continue card | Paused chapter only | Resume Home basics / Resume the Farm tour. Resume / Dismiss for now. | — | Resume changes the visible destination in the same interaction. |
| Slumber Party | Available | Create a Slumber Party / Join with a code / Do this later. | — | Join focuses the code field. |
| Slumber Party | Unavailable | Slumber Party is not available in this copy of Counting Sheep. Wind Down, the Farm, and Nights are ready. | — | No feature-flag language. |
| Screen Time | Onboarding + Settings | App limits let Counting Sheep cover the apps you choose while Wind Down is active… You can decline and come back to this later in Settings. | — | Consent before the system prompt. |
| Health | Settings | Apple Health can place optional sleep duration and stages beside your Wind Down record in Nights. It does not decide whether Wind Down was completed or whether Ollie finds a sheep. | — | Optional context, not a score. |
