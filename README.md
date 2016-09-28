slack-batch
===

Live at [rperce.net/slack-batch](//rperce.net/slack-batch).

Usage instructions:

1. Generate an [API key](https://api.slack.com/docs/oauth-test-tokens)---I haven't set up
   OAuth2 for this yet.
2. Fill in Field, Operator, and Comparison. Hover over the question mark icons to see
   what's a valid input. For `Field`, that is
    - `user`: user that uploaded the file
    - `time`: time file was uploaded
    - `limit`: number of results to return
    - `name`: actual filename (e.g. screenshotwhatever.png)
    - `title`: user-included title (e.g. "Hey, check this out!")
    - `is_public`: exactly what it says on the tin
    - `shared_in`: channel or private groups to filter searches to
    - `size`: filesize
   Once you've selected the field, the selections in Operator will filter to only those
   that make sense for the selected field (so, e.g., `user` will not have `<` and `>` in
   the list). `is` and `is not` do equality testing; `matches` does a regex comparison.
3. Add more filters by clicking the `+` button on the right, or clear unused filters with
   the `-`.
4. Hit `select * where` to query slack. File results can be inspected or individually or
   bulk deleted.


License
---
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

