# Armadilliards
My A level programming project for computer science.

You control an armadillo trapped on an 8-ball pool table, competing against your friends to destroy the most balls using a variety of abilities. Connect on local wifi to a central server, allowing you to create, search through and join a lobby with customisable player and lobby names, lobby win conditions and options for splitting a lobby into teams.

Networking code that allows for multiplayer is written from scratch, allowing players to host and join lobbies. 
Collisions between balls are optimised (in hindsight probably too much) for smoother performance.
All UI elements (buttons, animations, displaying cooldowns for abilities and healthbars) are made from scratch using primitive text and shapes.
3D models (and textures) used for the armadillos, 8-balls and the ability icons are made from scratch.
The particle system used is made from scratch, adapting existing code I wrote for rendering balls.

There are a significant number of bugs, which taught me the valuable lesson that new features should only be added after existing ones have been thoroughly tested, otherwise you end up in a knot of strange UI bugs and crashes.

