# Bubble Protocol Smart Contracts

This repository holds all the smart contracts use across the Bubble Protocol platform plus the project NFTs.  The repository is structured by sub-project.

## Bubble ID

Bubble ID uses a technology we call 'Proxy IDs'.  Proxy IDs are smart contracts that allow the owner to delegate powers to specific keys or other Proxy IDs.  This allows different applications on different devices to act on behalf of a user's Bubble ID without the need to transfer private keys across devices.

When delegating, the owner can restrict powers to pre-defined roles (see [proxy-roles](bubble-id/proxyid/proxy-roles.txt)).  Applications can therefore be restricted so that they only have the powers they need and no more.  If Proxy IDs are chained then those restrictions apply down the chain so that no delegated Proxy ID can delegate more powers than it has been granted.

Bubble Protocol uses chains of Proxy IDs for it's [Persona](bubble-id/personas/Persona.sol) and [Application ID](bubble-id/applications/ApplicationId.sol) contracts so that instances of applications on different devices can act on behalf a persona.

TODO: proxy id image

### Personas

When a user creates a new Persona in their [dashboard](https://datonavault.com/bubble), their genesis key deploys a [Persona contract](bubble-id/personas/Persona.sol) and permits their dashboard's [Application ID](bubble-id/applications/ApplicationId.sol) to act as an administrator of their persona.

The Persona contract also acts as a Smart Data Access Contract for the persona's bubble, which holds the persona's DID document, nickname and icon, and all of the personal data the user has entered for that persona.

## Bubble FS

Bubble FS uses [Smart Data Access](https://datona-lib.readthedocs.io/en/latest/what.html#) technology to provide private data storage for decentralised applications and organisations.  Data is stored in a 'bubble', which is where Bubble Protocol gets it's name.  

Bubbles can be large or trivially small. They are designed to be easily created and instantly accessible so that they can be used in everyday data transactions and decentralised applications. For example, the [Bubble Dashboard](https://datonavault.com/bubble) is a decentralised application that uses a bubble to store settings and metadata. This helps the application run smoothly and allows multiple installations across different devices to work as one.

A bubble is an off-chain, private, encrypted storage vault protected by an on-chain smart contract.  The smart contract that controls a bubble is known as a Smart Data Access Contract, or SDAC, and must implement the [sdac interface](bubble-fs/sdacs/SDAC.sol).

In this repository you will find some [example sdacs](bubble-fs/sdacs/examples) to use as a guide.  Another example is the [ERC721 controlled sdac](bubble-nfts/ERC721ControlledBubble.sol) used by the Bubble NFT project to provide the permissioned storage for its NFT images.

## Bubble NFTs

Bubble Protocol's project NFTs use a [tailored ERC721 contract](bubble-nfts/BubbleNFT.sol) specially designed to allow Proxy IDs to own NFTs.  This allows a user to manage and transfer their NFT using any application with the 'publish' role.  

The [project's NFT webpage](https://bubbleprotocol.com/nfts) uses the [Bubble Pass Chrome Extension](https://chrome.google.com/webstore/detail/bubble-pass/hdclcadfoglogdajchmemdgnggkboloa) to authenticate the user in the browser and rerieve any NFT images they own.  The images are retrieved from the project's NFT bubble, which permits only the owner of an NFT to access it's image.  See the `getPermissions` function within  [ERC721 controlled sdac](bubble-nfts/ERC721ControlledBubble.sol).

