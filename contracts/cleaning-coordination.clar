;; Cleaning Coordination Contract
;; Schedules panel washing and debris removal for community solar panels

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_PANEL (err u201))
(define-constant ERR_INVALID_SCHEDULE (err u202))
(define-constant ERR_ALREADY_SCHEDULED (err u203))
(define-constant ERR_NOT_SCHEDULED (err u204))
(define-constant ERR_TOKEN_MINT_FAILED (err u205))

;; Data Variables
(define-data-var cleaning-token-supply uint u500000)
(define-data-var next-cleaning-id uint u1)
(define-data-var cleaning-reward uint u25)

;; Data Maps
(define-map cleaning-schedules
  { cleaning-id: uint }
  {
    panel-id: uint,
    scheduled-date: uint,
    scheduled-by: principal,
    status: (string-ascii 20),
    cleaning-type: (string-ascii 30),
    estimated-duration: uint
  }
)

(define-map cleaning-completions
  { cleaning-id: uint }
  {
    completed-by: principal,
    completion-date: uint,
    effectiveness-rating: uint,
    notes: (string-ascii 200),
    verified: bool
  }
)

(define-map cleaning-tokens
  { holder: principal }
  { balance: uint }
)

(define-map panel-cleaning-history
  { panel-id: uint, cleaning-date: uint }
  {
    cleaning-id: uint,
    effectiveness: uint,
    cleaner: principal
  }
)

(define-map cleaning-volunteers
  { volunteer: principal }
  {
    total-cleanings: uint,
    rating: uint,
    active: bool
  }
)

;; Public Functions

;; Schedule a cleaning session
(define-public (schedule-cleaning (panel-id uint) (scheduled-date uint) (cleaning-type (string-ascii 30)) (estimated-duration uint))
  (let
    (
      (cleaning-id (var-get next-cleaning-id))
    )

    (asserts! (> panel-id u0) ERR_INVALID_PANEL)
    (asserts! (> scheduled-date block-height) ERR_INVALID_SCHEDULE)
    (asserts! (> estimated-duration u0) ERR_INVALID_SCHEDULE)

    (map-set cleaning-schedules
      { cleaning-id: cleaning-id }
      {
        panel-id: panel-id,
        scheduled-date: scheduled-date,
        scheduled-by: tx-sender,
        status: "scheduled",
        cleaning-type: cleaning-type,
        estimated-duration: estimated-duration
      }
    )

    (var-set next-cleaning-id (+ cleaning-id u1))

    ;; Reward scheduler with tokens
    (unwrap! (mint-cleaning-tokens tx-sender u5) ERR_TOKEN_MINT_FAILED)

    (ok cleaning-id)
  )
)

;; Complete a cleaning session
(define-public (complete-cleaning (cleaning-id uint) (effectiveness-rating uint) (notes (string-ascii 200)))
  (let
    (
      (schedule (unwrap! (map-get? cleaning-schedules { cleaning-id: cleaning-id }) ERR_NOT_SCHEDULED))
    )

    (asserts! (is-eq (get status schedule) "scheduled") ERR_INVALID_SCHEDULE)
    (asserts! (and (>= effectiveness-rating u1) (<= effectiveness-rating u10)) ERR_INVALID_SCHEDULE)

    ;; Update schedule status
    (map-set cleaning-schedules
      { cleaning-id: cleaning-id }
      (merge schedule { status: "completed" })
    )

    ;; Record completion
    (map-set cleaning-completions
      { cleaning-id: cleaning-id }
      {
        completed-by: tx-sender,
        completion-date: block-height,
        effectiveness-rating: effectiveness-rating,
        notes: notes,
        verified: false
      }
    )

    ;; Update panel cleaning history
    (map-set panel-cleaning-history
      { panel-id: (get panel-id schedule), cleaning-date: block-height }
      {
        cleaning-id: cleaning-id,
        effectiveness: effectiveness-rating,
        cleaner: tx-sender
      }
    )

    ;; Update volunteer stats
    (let
      (
        (volunteer-stats (default-to { total-cleanings: u0, rating: u5, active: true }
                                   (map-get? cleaning-volunteers { volunteer: tx-sender })))
      )

      (map-set cleaning-volunteers
        { volunteer: tx-sender }
        {
          total-cleanings: (+ (get total-cleanings volunteer-stats) u1),
          rating: (/ (+ (* (get rating volunteer-stats) (get total-cleanings volunteer-stats)) effectiveness-rating)
                    (+ (get total-cleanings volunteer-stats) u1)),
          active: true
        }
      )
    )

    ;; Reward cleaner with tokens based on effectiveness
    (unwrap! (mint-cleaning-tokens tx-sender (* (var-get cleaning-reward) effectiveness-rating)) ERR_TOKEN_MINT_FAILED)

    (ok true)
  )
)

;; Verify cleaning completion
(define-public (verify-cleaning (cleaning-id uint))
  (let
    (
      (completion (unwrap! (map-get? cleaning-completions { cleaning-id: cleaning-id }) ERR_NOT_SCHEDULED))
    )

    (asserts! (not (get verified completion)) ERR_INVALID_SCHEDULE)

    (map-set cleaning-completions
      { cleaning-id: cleaning-id }
      (merge completion { verified: true })
    )

    ;; Additional reward for verification
    (unwrap! (mint-cleaning-tokens (get completed-by completion) u10) ERR_TOKEN_MINT_FAILED)

    (ok true)
  )
)

;; Register as cleaning volunteer
(define-public (register-volunteer)
  (begin
    (map-set cleaning-volunteers
      { volunteer: tx-sender }
      {
        total-cleanings: u0,
        rating: u5,
        active: true
      }
    )

    ;; Welcome bonus
    (unwrap! (mint-cleaning-tokens tx-sender u50) ERR_TOKEN_MINT_FAILED)

    (ok true)
  )
)

;; Mint cleaning tokens
(define-private (mint-cleaning-tokens (recipient principal) (amount uint))
  (let
    (
      (current-balance (default-to u0 (get balance (map-get? cleaning-tokens { holder: recipient }))))
    )

    (map-set cleaning-tokens
      { holder: recipient }
      { balance: (+ current-balance amount) }
    )

    (ok amount)
  )
)

;; Read-only Functions

;; Get cleaning schedule
(define-read-only (get-cleaning-schedule (cleaning-id uint))
  (map-get? cleaning-schedules { cleaning-id: cleaning-id })
)

;; Get cleaning completion details
(define-read-only (get-cleaning-completion (cleaning-id uint))
  (map-get? cleaning-completions { cleaning-id: cleaning-id })
)

;; Get cleaning token balance
(define-read-only (get-cleaning-token-balance (holder principal))
  (default-to u0 (get balance (map-get? cleaning-tokens { holder: holder })))
)

;; Get volunteer information
(define-read-only (get-volunteer-info (volunteer principal))
  (map-get? cleaning-volunteers { volunteer: volunteer })
)

;; Get panel cleaning history
(define-read-only (get-panel-cleaning-history (panel-id uint) (cleaning-date uint))
  (map-get? panel-cleaning-history { panel-id: panel-id, cleaning-date: cleaning-date })
)
