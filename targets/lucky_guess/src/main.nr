use aztec::macros::aztec;

#[aztec]
pub contract LuckyGuess {
    use aztec::{
        macros::{functions::{external, initializer}, storage::storage},
        oracle::random::random,
        protocol::address::AztecAddress,
        state_vars::PublicImmutable,
    };
    use flag_emitter::FlagEmitter;

    #[storage]
    struct Storage<Context> {
        flag_emitter: PublicImmutable<AztecAddress, Context>,
    }

    #[external("public")]
    #[initializer]
    fn constructor(flag_emitter: AztecAddress) {
        self.storage.flag_emitter.initialize(flag_emitter);
    }

    /// The Cheshire Cat challenges you to Wonderland Roshambo.
    /// Five rounds. Five chances. Only the luckiest may pass.
    ///
    ///   0 = Rock
    ///   1 = Paper
    ///   2 = Scissors
    ///
    /// "We're all mad here," grins the Cat.
    #[external("private")]
    fn capture_flag(moves: [u8; 5]) {
        for i in 0..5 {
            assert(moves[i] < 3, "Only three choices exist beyond the looking glass");

            // Safety: the Cheshire Cat draws fate from the looking glass
            let fate = unsafe { random() };
            let fate_bytes: [u8; 32] = fate.to_le_bytes();
            let cat_move: u8 = fate_bytes[0] % 3;

            let result: u8 = (moves[i] + 3 - cat_move) % 3;
            assert(result == 1, "The Cheshire Cat grins and fades away");
        }

        let solver = self.msg_sender();
        self.enqueue(FlagEmitter::at(self.storage.flag_emitter.read()).emit_flag(solver));
    }
}
