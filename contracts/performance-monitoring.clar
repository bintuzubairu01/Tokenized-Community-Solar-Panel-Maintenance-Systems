;; Performance Monitoring Contract
;; Tracks energy production and efficiency metrics for community solar panels

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_PANEL (err u101))
(define-constant ERR_INVALID_DATA (err u102))
(define-constant ERR_ALREADY_REPORTED (err u103))
(define-constant ERR_TOKEN_MINT_FAILED (err u104))

;; Data Variables
(define-data-var total-panels uint u0)
(define-data-var total-energy-produced uint u0)
(define-data-var performance-token-supply uint u1000000)

;; Data Maps
(define-map panels
  { panel-id: uint }
  {
    owner: principal,
    capacity: uint,
    installation-date: uint,
    total-production: uint,
    efficiency-rating: uint,
    active: bool
  }
)

(define-map daily-performance
  { panel-id: uint, date: uint }
  {
    energy-produced: uint,
    efficiency: uint,
    reporter: principal,
    timestamp: uint
  }
)

(define-map performance-tokens
  { holder: principal }
  { balance: uint }
)

(define-map panel-operators
  { panel-id: uint }
  { operator: principal, authorized: bool }
)

;; Public Functions

;; Register a new solar panel
(define-public (register-panel (panel-id uint) (capacity uint) (installation-date uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (> capacity u0) ERR_INVALID_DATA)
    (asserts! (is-none (map-get? panels { panel-id: panel-id })) ERR_INVALID_PANEL)

    (map-set panels
      { panel-id: panel-id }
      {
        owner: tx-sender,
        capacity: capacity,
        installation-date: installation-date,
        total-production: u0,
        efficiency-rating: u100,
        active: true
      }
    )

    (var-set total-panels (+ (var-get total-panels) u1))
    (ok panel-id)
  )
)

;; Report daily performance data
(define-public (report-performance (panel-id uint) (date uint) (energy-produced uint) (efficiency uint))
  (let
    (
      (panel (unwrap! (map-get? panels { panel-id: panel-id }) ERR_INVALID_PANEL))
      (existing-report (map-get? daily-performance { panel-id: panel-id, date: date }))
    )

    (asserts! (get active panel) ERR_INVALID_PANEL)
    (asserts! (> energy-produced u0) ERR_INVALID_DATA)
    (asserts! (and (>= efficiency u0) (<= efficiency u200)) ERR_INVALID_DATA)
    (asserts! (is-none existing-report) ERR_ALREADY_REPORTED)

    ;; Record performance data
    (map-set daily-performance
      { panel-id: panel-id, date: date }
      {
        energy-produced: energy-produced,
        efficiency: efficiency,
        reporter: tx-sender,
        timestamp: block-height
      }
    )

    ;; Update panel total production
    (map-set panels
      { panel-id: panel-id }
      (merge panel { total-production: (+ (get total-production panel) energy-produced) })
    )

    ;; Update global energy production
    (var-set total-energy-produced (+ (var-get total-energy-produced) energy-produced))

    ;; Reward reporter with performance tokens
    (unwrap! (mint-performance-tokens tx-sender u10) ERR_TOKEN_MINT_FAILED)

    (ok true)
  )
)

;; Mint performance tokens for data submission
(define-private (mint-performance-tokens (recipient principal) (amount uint))
  (let
    (
      (current-balance (default-to u0 (get balance (map-get? performance-tokens { holder: recipient }))))
    )

    (map-set performance-tokens
      { holder: recipient }
      { balance: (+ current-balance amount) }
    )

    (ok amount)
  )
)

;; Calculate panel efficiency over time period
(define-public (calculate-efficiency (panel-id uint) (start-date uint) (end-date uint))
  (let
    (
      (panel (unwrap! (map-get? panels { panel-id: panel-id }) ERR_INVALID_PANEL))
    )

    (asserts! (<= start-date end-date) ERR_INVALID_DATA)

    ;; This would iterate through dates in a real implementation
    ;; For now, return a placeholder calculation
    (ok u85)
  )
)

;; Read-only Functions

;; Get panel information
(define-read-only (get-panel-info (panel-id uint))
  (map-get? panels { panel-id: panel-id })
)

;; Get daily performance data
(define-read-only (get-daily-performance (panel-id uint) (date uint))
  (map-get? daily-performance { panel-id: panel-id, date: date })
)

;; Get performance token balance
(define-read-only (get-performance-token-balance (holder principal))
  (default-to u0 (get balance (map-get? performance-tokens { holder: holder })))
)

;; Get total system statistics
(define-read-only (get-system-stats)
  {
    total-panels: (var-get total-panels),
    total-energy-produced: (var-get total-energy-produced),
    token-supply: (var-get performance-token-supply)
  }
)
