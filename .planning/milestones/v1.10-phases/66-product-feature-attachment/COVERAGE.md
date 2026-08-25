# API Coverage — Stripe Product Features

> Full coverage by default. The authoritative Product Feature endpoint family is covered without subtraction.

| capability | decision | reason |
|---|---|---|
| Create attachment (collection POST) | INTEGRATE | |
| Retrieve attachment (item GET) | INTEGRATE | |
| List attachments (collection GET) | INTEGRATE | |
| Completely enumerate attachments (`stream!`) | INTEGRATE | |
| Delete attachment (item DELETE) | INTEGRATE | |

Stripe exposes no Product Feature attachment update endpoint, so there is no update capability to integrate or opt out of.
