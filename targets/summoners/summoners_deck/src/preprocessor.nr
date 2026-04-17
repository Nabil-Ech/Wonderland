use aztec::{note::HintedNote, protocol::constants::MAX_NOTE_HASH_READ_REQUESTS_PER_CALL};
use uint_note::UintNote;

pub fn filter_note(
    notes: [Option<HintedNote<UintNote>>; MAX_NOTE_HASH_READ_REQUESTS_PER_CALL],
    _args: Field,
) -> [Option<HintedNote<UintNote>>; MAX_NOTE_HASH_READ_REQUESTS_PER_CALL] {
    let mut selected: [Option<HintedNote<UintNote>>; MAX_NOTE_HASH_READ_REQUESTS_PER_CALL] =
        [Option::none(); MAX_NOTE_HASH_READ_REQUESTS_PER_CALL];
    let mut last_idx: u32 = MAX_NOTE_HASH_READ_REQUESTS_PER_CALL as u32;

    for i in 0..notes.len() {
        if notes[i].is_some() {
            last_idx = i as u32;
        }
    }

    if last_idx < MAX_NOTE_HASH_READ_REQUESTS_PER_CALL as u32 {
        selected[last_idx] = notes[last_idx];
    }
    selected
}
