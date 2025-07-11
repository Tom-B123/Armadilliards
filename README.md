# Armadilliards
My A level programming project for computer science.

You control an armadillo trapped on an 8-ball pool table, competing against your friends to destroy the most balls using a variety of abilities. Connect on local wifi to a central server, allowing you to create, search through and join a lobby with customisable player and lobby names, lobby win conditions and options for splitting a lobby into teams.

Networking code that allows for multiplayer is written from scratch, allowing players to host and join lobbies. 
Collisions between balls are optimised (in hindsight probably too much) for smoother performance.
All UI elements (buttons, animations, displaying cooldowns for abilities and healthbars) are made from scratch using primitive text and shapes.
3D models (and textures) used for the armadillos, 8-balls and the ability icons are made from scratch.
The particle system used is made from scratch, adapting existing code I wrote for rendering balls.

There are a significant number of bugs, which taught me the valuable lesson that new features should only be added after existing ones have been thoroughly tested, otherwise you end up in a knot of strange UI bugs and crashes.

## How To Play
- Downoad the mainserver.js file and the .love executable.
- Run the main server using "node mainserver.js".
- If this gives the desired output of: "Server listening on 0.0.0.0:500" then the server is correctly hosted.
- Now you can run the .love file to launch the game client, where you should navigate to "click to start" then "multiplayer".
- If there is no error displayed connecting to multiplayer, congratulations! You can now click the grey box to change your player name, and host or join a locally hosted lobby. If there are many lobbies, you can scroll through them.
- Once in the lobby, the "t" key opens a chat menu, where you can type a message to the lobby.
- The grey "team 1" button can be clicked to change your team. The left and right arrows next to the ability icons (looks like "< O >") can change which ability is bound to0 the left and right mouse buttons: dash, rope or shoot. 
- The left and right keys can change which map is selected.
- You can now run around with arrow keys and the mouse buttons to fulfil the objective, selected by pressing escape -> game settings while in the lobby. The game ends when the objective bar is full, meaning a team has won the game.

## Note
If there are connection issues, I believe the local ip address used in the net.lua file is hard coded, so you may need to run ipconfig in the command prompt and put your host device's ip address as the mainIP variable. I highly doubt that getting the game to run on another machine will be easy, as this project wasn't designed to be easily installed and played on other machines :(
