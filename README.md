GM_AP is an Archipelago Client "Library" for Garry's Mod, it was originally made for another GMod AP project that is was later separated from so it could be shared across different GMod AP Integrations. That being said, it's not very well documented and was made when I was a much less experienced coder, so I'm not sure how useful it'll actually be to other developers.

This "Library" just uses a websocket module and is otherwise coded in pure Lua, so it suffers from a notable limitation: Since GMods Lua environment gets shut down between map transitions, GMAP has to reconnect to AP after every map change.

Using it requires [GWSockets](https://github.com/FredyH/GWSockets) to be installed.

The Archipelago Logo, which was used as the base for icons in this project, is © 2022 by Krista Corkos and Christopher Wilson and is licensed under Attribution-NonCommercial 4.0 International. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc/4.0/