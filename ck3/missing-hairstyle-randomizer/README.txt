Missing hairstyle randomizer
----------------------------

Creates decision to add random hairstyle to all characters made bald by 1.3.0 patch changes applied to 1.2.x saves.

Should only be needed for those who are loading savegames from CK3 1.2.x with 1.3.0 and are being put off by half of the known world going bald.

Decision is a one-off to add a flag to every living character, which would apply a random hairstyle modifier to their portrait. It comes before all other portrait modifiers, so ideally should not override any existing - or rather surviving - hairs.

Currently it picks hairstyle at random from all_hairstyles template for simplicitly, without tying it to clothing, culture, etc - it can be done better, but eh, anything not-all-bald is fine, and descendants of these characters should have proper hairstyles inherited from genes, not this one-off modifier.

Not too well-tested, just made it to fix this issue with my save, but 1.3.0 has enough other problems to maybe wait for 1.3.1 or such before going back to that game...
