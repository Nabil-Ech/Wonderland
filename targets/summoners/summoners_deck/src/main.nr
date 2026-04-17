mod preprocessor;

use aztec::macros::aztec;

/// The Summoner's Deck is an ancient and cursed set of omen cards.
/// Those who seek immortality must attempt a forbidden rite whispered
/// about only in the margins of forgotten grimoires.
///
/// The rite cannot begin lightly. The deck must be consulted until
/// five omens stand before the summoner -- no fewer will stir the veil.
///
/// These omens must then be placed in the one true order, an order
/// unknowable to the living and remembered only by something that
/// was never born into this world.
///
/// A phantom must read the cards.
/// Not a creature of flesh. Not a mind that remembers its birth.
/// Something without origin, without memory, without a name.
///
/// The sequence is etched into the phantom's soul.
/// No living mind can see it. No living mind can know it.
///
/// Only when the omen cards stand in their destined order
/// will the veil part and the flag be revealed.
#[aztec]
pub contract SummonersDeck {
    use aztec::{
        history::deployment::{
            assert_contract_bytecode_was_not_published_by, assert_contract_was_not_initialized_by,
        },
        macros::{functions::{authorize_once, external, initializer}, storage::storage},
        messages::message_delivery::MessageDelivery,
        note::{note_getter_options::NoteGetterOptions, note_interface::NoteProperties},
        oracle::get_contract_instance::get_contract_instance,
        protocol::{address::AztecAddress, traits::{Packable, ToField}},
        state_vars::{Owned, PrivateSet, PublicImmutable},
        utils::comparison::Comparator,
    };
    use flag_emitter::FlagEmitter;
    use uint_note::UintNote;

    #[storage]
    struct Storage<Context> {
        flag_emitter: PublicImmutable<AztecAddress, Context>,
        omens: Owned<PrivateSet<UintNote, Context>, Context>,
    }

    /// Begin the ritual.
    #[external("public")]
    #[initializer]
    fn begin_ritual(flag_emitter: AztecAddress) {
        self.storage.flag_emitter.initialize(flag_emitter);
    }

    /// Draw five omen cards from the Summoner's Deck.
    ///
    /// 1 -- The Candle of Graves
    /// 2 -- The Veil Incense
    /// 3 -- The Black Mirror
    /// 4 -- The Mourning Bell
    /// 5 -- The Spirit Chalice
    ///
    /// The deck is cursed. It always deals the same five omens,
    /// in the same order. The curse cannot be broken.
    #[external("private")]
    fn draw(player: AztecAddress) {
        for i in 0..5 {
            let value: u128 = (i as u128) + 1;
            self.storage.omens.at(player).insert(UintNote { value }).deliver(
                MessageDelivery.ONCHAIN_UNCONSTRAINED,
            );
        }
    }

    /// Discard omen cards.
    ///
    /// The curse relents -- but only so far. Up to three cards may be
    /// discarded at once. Pass 0 for any slot to skip it.
    #[external("private")]
    fn discard(player: AztecAddress, values: [u128; 3]) {
        for i in 0..3 {
            let v = values[i];
            if v != 0 {
                let options = NoteGetterOptions::with_preprocessor(
                    super::preprocessor::filter_note,
                    0,
                )
                    .select(UintNote::properties().value, Comparator.EQ, v);
                let notes = self.storage.omens.at(player).pop_notes(options);
                assert(notes.len() > 0, "no matching card found");
            }
        }
    }

    /// Perform the summoning ritual.
    ///
    /// The chosen omens must be placed in the order written in the
    /// phantom's soul. Should the order be wrong, the veil will not move
    /// and the ritual will fail.
    ///
    /// Beware who dares to complete the rite.
    /// Some truths are not meant to be witnessed by the one who calls them.
    ///
    /// Only the unborn may read the truth of the omens.
    #[authorize_once("reader", "authwit_nonce")]
    #[external("private")]
    fn summon(reader: AztecAddress, authwit_nonce: Field) {
        let caller = self.msg_sender();
        let header = self.context.get_anchor_block_header();

        // The dead cannot read their own cards.
        assert(caller != reader, "caller must not be the reader");

        // Only the unborn may speak -- no form, no name.
        assert_contract_bytecode_was_not_published_by(header, caller);

        let instance = get_contract_instance(caller);
        assert_contract_was_not_initialized_by(header, caller, instance.initialization_hash);

        // The phantom's essence determines the sequence.
        let class_digit = (instance.contract_class_id.to_field() as u64 % 4) + 1;
        let combined = (caller.to_field() as u64) ^ (instance.salt as u64);
        let target = derive_sequence(class_digit, combined % 1000);

        let options = NoteGetterOptions::<UintNote, <UintNote as Packable>::N, Field, Field>::new()
            .set_limit(6);
        let cards = self.storage.omens.at(reader).get_notes(options);

        let mut values: [u128; 6] = [0; 6];
        for i in 0..6 {
            if i < cards.len() {
                values[i] = cards.get_unchecked(i).note.value;
            }
        }

        for i in 0..6 {
            assert(values[i] == target[i], "the spread is wrong");
        }

        self.enqueue(FlagEmitter::at(self.storage.flag_emitter.read()).emit_flag(reader));
    }

    /// The phantom carries the memory of the ritual within its essence.
    /// From this essence the true order of the omen cards is revealed.
    /// If the omens do not match what is written there, the ritual collapses
    /// and the veil remains closed.
    #[contract_library_method]
    fn derive_sequence(class_digit: u64, xor_tail: u64) -> [u128; 6] {
        let mut val = xor_tail;
        let mut digits: [u64; 4] = [0; 4];
        digits[3] = class_digit;
        for i in 0..3 {
            digits[i] = val % 10;
            val /= 10;
        }

        let mut sum: u64 = 0;
        let mut product: u64 = 1;
        for i in 0..4 {
            assert(digits[i] >= 1, "invalid omen");
            assert(digits[i] <= 4, "invalid omen");
            sum += digits[i];
            product *= digits[i];
        }
        assert(sum == 10, "invalid omen");
        assert(product == 24, "invalid omen");

        [5, digits[3] as u128, digits[2] as u128, digits[1] as u128, digits[0] as u128, 0]
    }
}
