;; Learning Quest System Smart Contract
;; A gamified educational platform for completing learning quests and earning knowledge tokens

;; Constants
(define-constant KNOWLEDGE_VAULT_LIMIT u1000000)
(define-constant BASE_QUEST_REWARD u10)
(define-constant MASTERY_BONUS u2)
(define-constant MAX_MASTERY_LEVEL u7)
(define-constant ERR_INVALID_QUEST u1)
(define-constant ERR_NO_KNOWLEDGE_TOKENS u2)
(define-constant ERR_VAULT_LIMIT_EXCEEDED u3)
(define-constant BLOCKS_PER_DAY u144)
(define-constant STUDY_MULTIPLIER u2)
(define-constant MIN_STUDY_COMMITMENT u288)
(define-constant DROPOUT_PENALTY u10)

;; Data Variables
(define-data-var total-knowledge-tokens-minted uint u0)
(define-data-var total-quests-completed uint u0)
(define-data-var education-admin principal tx-sender)

;; Data Maps
(define-map student-quests principal uint)
(define-map student-knowledge-tokens principal uint)
(define-map quest-start-time principal uint)
(define-map student-mastery principal uint)
(define-map student-last-study principal uint)
(define-map student-staked-tokens principal uint)
(define-map student-stake-start-block principal uint)

;; Public Functions

(define-public (initiate-quest (difficulty uint))
  (let
    (
      (student tx-sender)
    )
    (asserts! (> difficulty u0) (err ERR_INVALID_QUEST))
    (map-set quest-start-time student burn-block-height)
    (ok true)
  )
)

(define-public (complete-quest (difficulty uint))
  (let
    (
      (student tx-sender)
      (start-block (default-to u0 (map-get? quest-start-time student)))
      (blocks-studied (- burn-block-height start-block))
      (last-study-block (default-to u0 (map-get? student-last-study student)))
      (current-mastery (default-to u0 (map-get? student-mastery student)))
      (capped-mastery (if (<= current-mastery MAX_MASTERY_LEVEL) current-mastery MAX_MASTERY_LEVEL))
      (knowledge-reward (+ BASE_QUEST_REWARD (* capped-mastery MASTERY_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-studied difficulty)) (err ERR_INVALID_QUEST))
    (map-set student-quests student (+ (default-to u0 (map-get? student-quests student)) u1))
    (map-set student-knowledge-tokens student (+ (default-to u0 (map-get? student-knowledge-tokens student)) knowledge-reward))
    (if (< (- burn-block-height last-study-block) BLOCKS_PER_DAY)
      (map-set student-mastery student (+ current-mastery u1))
      (map-set student-mastery student u1)
    )
    (map-set student-last-study student burn-block-height)
    (var-set total-quests-completed (+ (var-get total-quests-completed) u1))
    (var-set total-knowledge-tokens-minted (+ (var-get total-knowledge-tokens-minted) knowledge-reward))
    (asserts! (<= (var-get total-knowledge-tokens-minted) KNOWLEDGE_VAULT_LIMIT) (err ERR_VAULT_LIMIT_EXCEEDED))
    (ok knowledge-reward)
  )
)

(define-public (withdraw-knowledge-tokens)
  (let
    (
      (student tx-sender)
      (token-balance (default-to u0 (map-get? student-knowledge-tokens student)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_KNOWLEDGE_TOKENS))
    (map-set student-knowledge-tokens student u0)
    (ok token-balance)
  )
)

;; Staking Features

(define-public (stake-for-learning (amount uint))
  (let
    (
      (student tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_QUEST))
    (asserts! (>= (var-get total-knowledge-tokens-minted) amount) (err ERR_VAULT_LIMIT_EXCEEDED))
    (map-set student-staked-tokens student amount)
    (map-set student-stake-start-block student burn-block-height)
    (var-set total-knowledge-tokens-minted (- (var-get total-knowledge-tokens-minted) amount))
    (ok amount)
  )
)

(define-public (unstake-learning-tokens)
  (let
    (
      (student tx-sender)
      (staked-amount (default-to u0 (map-get? student-staked-tokens student)))
      (stake-start-block (default-to u0 (map-get? student-stake-start-block student)))
      (blocks-staked (- burn-block-height stake-start-block))
      (penalty (if (< blocks-staked MIN_STUDY_COMMITMENT) (/ (* staked-amount DROPOUT_PENALTY) u100) u0))
      (final-amount (- staked-amount penalty))
    )
    (asserts! (> staked-amount u0) (err ERR_NO_KNOWLEDGE_TOKENS))
    (map-set student-staked-tokens student u0)
    (map-set student-stake-start-block student u0)
    (var-set total-knowledge-tokens-minted (+ (var-get total-knowledge-tokens-minted) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-quest-count (user principal))
  (default-to u0 (map-get? student-quests user))
)

(define-read-only (get-knowledge-balance (user principal))
  (default-to u0 (map-get? student-knowledge-tokens user))
)

(define-read-only (get-mastery-level (user principal))
  (default-to u0 (map-get? student-mastery user))
)

(define-read-only (get-learning-stats)
  {
    total-quests: (var-get total-quests-completed),
    total-knowledge-tokens: (var-get total-knowledge-tokens-minted)
  }
)

;; Private Functions

(define-private (is-education-admin)
  (is-eq tx-sender (var-get education-admin))
)
