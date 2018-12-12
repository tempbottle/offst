@0xe34d46ee2fe7213e;

using import "common.capnp".Signature;
using import "common.capnp".PublicKey;
using import "common.capnp".Hash;
using import "common.capnp".RandNonce;
using import "common.capnp".Uid;
using import "common.capnp".CustomUInt128;

using import "funder.capnp".FriendsRoute;

# IndexClient <-> IndexServer
###################

# Request a direct route of friends from the source node to the destination
# node.
struct DirectRoute {
        sourcePublicKey @0: PublicKey;
        destinationPublicKey @1: PublicKey;
}

# A loop from myself through given friend, back to myself.
# This is used for money rebalance when we owe the friend money.
# self -> friend -> ... -> ... -> self
struct LoopFromFriendRoute {
        friendPublicKey @0: PublicKey;
}

# A loop from myself back to myself through given friend.
# This is used for money rebalance when the friend owe us money.
# self -> ... -> ... -> friend -> self
struct LoopToFriendRoute {
        friendPublicKey @0: PublicKey;
}

# IndexClient -> IndexServer
struct RequestFriendsRoute {
        requestRouteId @0: CustomUInt128;
        capacity @1: CustomUInt128;
        # Wanted capacity for the route. 
        # 0 means we want to optimize for capacity?
        routeType :union {
                direct @2: DirectRoute;
                loopFromFriend @3: LoopFromFriendRoute;
                loopToFriend @4: LoopToFriendRoute;
        }
}

struct FriendsRouteWithCapacity {
        route @0: FriendsRoute;
        capacity @1: CustomUInt128;
}

# IndexServer -> IndexClient
struct ResponseFriendsRoute {
        requestRouteId @0: CustomUInt128;
        routes @1: List(FriendsRouteWithCapacity);
}

struct UpdateFriend {
        publicKey @0: PublicKey;
        # Friend's public key
        sendCapacity @1: CustomUInt128;
        # To denote remote requests closed, assign 0 to sendCapacity
        recvCapacity @2: CustomUInt128;
        # To denote local requests closed, assign 0 to recvCapacity
}


# IndexClient -> IndexServer
struct Mutation {
        union {
                updateFriend @0: UpdateFriend;
                removeFriend @1: PublicKey;
        }
}

struct MutationsUpdate {
        nodePublicKey @0: PublicKey;
        # Public key of the node sending the mutations.
        mutations @1: List(Mutation);
        # List of mutations to relationships with direct friends.
        timeHash @2: Hash;
        # A time hash (Given by the server previously). 
        # This is used as time, proving that this message was signed recently.
        sessionId @3: Uid;
        # A randomly generated sessionId. The counter is related to this session Id.
        counter @4: UInt64;
        # Incrementing counter, making sure that mutations are received in the correct order.
        # For a new session, the counter should begin from 0 and increment by 1 for every MutationsUpdate message.
        # When a new connection is established, a new sesionId should be randomly generated.
        randNonce @5: RandNonce;
        # Rand nonce, used as a security measure for the next signature.
        signature @6: Signature;
        # signature(sha_512_256("MUTATIONS_UPDATE") || 
        #           nodePublicKey ||
        #           mutation || 
        #           timeHash || 
        #           counter || 
        #           randNonce)
}

struct TimeProofLink {
        hashes @0: List(Hash);
        # List of hashes that produce a certain hash
        # sha_512_256("TIME_HASH" || hashes)
        index @1: UInt16;
        # Index pointing to a specific hash on the hashes list.
}

struct ForwardMutationsUpdate {
        mutationsUpdate @0: MutationsUpdate;
        timeProof @1: List(TimeProofLink);
        # A proof that MutationsUpdate was signed recently
        # Receiver should verify:
        # - sha_512_256(hashes[0]) == MutationsUpdate.timeHash,
        # - For all i < n - 1 : hashes[i][index[i]] == sha_512_256(hashes[i+1])
        # - hashes[n-1][index[n-1]] is some recent time hash generated by the receiver.
}

###################################################

struct ServerToClient {
        union {
                timeHash @0: Hash;
                responseFriendsRoute @1: ResponseFriendsRoute;
        }
}


struct ClientToServer {
        union {
                mutationsUpdate @0: MutationsUpdate;
                requestFriendsRoute @1: RequestFriendsRoute;
        }
}


struct ServerToServer {
        union {
                timeHash @0: Hash;
                forwardMutationsUpdate @1: ForwardMutationsUpdate;
        }
}