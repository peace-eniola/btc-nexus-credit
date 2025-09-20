;; Title: BTC Nexus Credit Protocol
;;
;; Summary: Revolutionary Bitcoin-native lending infrastructure built on Stacks
;;          that transforms idle sBTC into productive credit opportunities.
;;
;; Description:
;;   BTC Nexus Credit Protocol pioneers the future of Bitcoin-secured lending
;;   by combining the security of Bitcoin with the programmability of Stacks.
;;   Our protocol creates a seamless bridge between Bitcoin holders and 
;;   credit seekers through intelligent risk assessment and automated 
;;   liquidity management.
;;
;;   Key Features:
;;   - Six-tier dynamic credit scoring (0-5 tiers) with progressive limits
;;   - AI-powered risk assessment using on-chain behavior patterns  
;;   - Automated yield generation for Bitcoin liquidity providers
;;   - Self-executing smart contracts with zero counterparty risk
;;   - Institutional-grade compliance with full transparency
;;
;;   Whether you're a Bitcoin maximalist seeking yield or an entrepreneur
;;   needing quick liquidity, BTC Nexus Credit Protocol democratizes
;;   access to Bitcoin-backed credit markets while preserving the ethos
;;   of decentralization and self-sovereignty.
;;

;; ERROR CONSTANTS
(define-constant ERR_UNAUTHORIZED_ACCESS (err u100))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u101))
(define-constant ERR_INVALID_LENDER (err u102))
(define-constant ERR_POOL_LIMIT_EXCEEDED (err u103))
(define-constant ERR_CREDIT_INELIGIBLE (err u104))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u105))
(define-constant ERR_FUNDS_LOCKED (err u106))
(define-constant ERR_BLOCK_DATA_UNAVAILABLE (err u107))

;; CREDIT TIER LIMITS (denominated in satoshis)
(define-constant TIER_0_LIMIT u10000)     ;; 0.0001 sBTC - Starter
(define-constant TIER_1_LIMIT u50000)     ;; 0.0005 sBTC - Basic
(define-constant TIER_2_LIMIT u100000)    ;; 0.001 sBTC - Standard
(define-constant TIER_3_LIMIT u300000)    ;; 0.003 sBTC - Premium
(define-constant TIER_4_LIMIT u500000)    ;; 0.005 sBTC - Elite
(define-constant TIER_5_LIMIT u1000000)   ;; 0.01 sBTC - Institutional

;; DATA STRUCTURES

;; Lender position tracking
(define-map lender_positions principal {
  balance: uint,
  locked_block: uint,
  unlock_block: uint
})

;; Active loan management
(define-map active_loans principal {
  amount: uint,
  due_block: uint,
  interest_rate: uint,
  issued_block: uint
})

;; Credit history tracking
(define-map credit_history principal {
  total_loans: uint,
  on_time_payments: uint,
  late_payments: uint
})

;; PROTOCOL CONFIGURATION
(define-data-var total_liquidity_pool uint u0)
(define-data-var protocol_admin principal tx-sender)
(define-data-var base_interest_rate uint u15)           ;; 15% annual base rate
(define-data-var loan_term_days uint u14)              ;; 14-day standard term
(define-data-var lender_lock_period uint u0)           ;; Lender fund lock period

;; UTILITY FUNCTIONS

;; Admin access verification
(define-private (verify-admin-access)
  (begin
    (asserts! (is-eq contract-caller (var-get protocol_admin)) false)
    true
  )
)

;; Blockchain timing calculations
(define-read-only (seconds-per-block)
  (* u10 u60) ;; 600 seconds per block on Stacks
)

;; Convert days to blocks
(define-private (days-to-blocks (days uint))
  (/ (* days u24 u60 u60) (seconds-per-block))
)

;; Calculate 3-month rolling balance average
(define-private (calculate-rolling-balance (account principal))
  (let (
      (block_1_month (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (days-to-blocks u1))) u0))
      (block_2_month (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (days-to-blocks u31))) u0))
      (block_3_month (unwrap! (get-stacks-block-info? id-header-hash (- stacks-block-height (days-to-blocks u61))) u0))
    )
    (/
      (+ 
        (at-block block_1_month (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance account) u0))
        (at-block block_2_month (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance account) u0))
        (at-block block_3_month (unwrap! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance account) u0))
      ) 
      u3
    )
  )
)

;; Determine credit limit based on score
(define-private (determine-credit-limit (credit_score uint))
  (begin
    (asserts! (> credit_score u300) TIER_0_LIMIT)
    (asserts! (> credit_score u450) TIER_1_LIMIT)
    (asserts! (> credit_score u600) TIER_2_LIMIT)
    (asserts! (> credit_score u750) TIER_3_LIMIT)
    (asserts! (> credit_score u900) TIER_4_LIMIT)
    TIER_5_LIMIT
  )
)

;; Process payment and update credit history
(define-private (process-payment-and-update-history (borrower principal))
  (let
    (
      (credit_record (default-to 
        { 
          total_loans: u0,
          on_time_payments: u0,
          late_payments: u0,
        }
        (map-get? credit_history borrower)
      ))
      (loan_due_block (default-to u0 (get due_block (map-get? active_loans borrower))))
    ) 
    (if (<= stacks-block-height loan_due_block)
      (map-set credit_history borrower {
        total_loans: (get total_loans credit_record),
        on_time_payments: (+ (get on_time_payments credit_record) u1),
        late_payments: (get late_payments credit_record),
      })
      (map-set credit_history borrower {
        total_loans: (get total_loans credit_record),
        on_time_payments: (get on_time_payments credit_record),
        late_payments: (+ (get late_payments credit_record) u1),
      })
    )
    (map-delete active_loans borrower)
  )
)

;; Calculate activity score based on balance
(define-private (calculate-activity_score (rolling_balance uint))
  (begin 
    (asserts! (> rolling_balance u0) u0)
    (asserts! (>= rolling_balance TIER_0_LIMIT) u100)
    (asserts! (>= rolling_balance TIER_1_LIMIT) u220)
    (asserts! (>= rolling_balance TIER_2_LIMIT) u240)
    (asserts! (>= rolling_balance TIER_3_LIMIT) u260)
    (asserts! (>= rolling_balance TIER_4_LIMIT) u280)
    u300
  )
)

;; Calculate payment reliability score
(define-private (calculate-payment_score (total_loans uint) (on_time_payments uint) (late_payments uint))
  (if (> on_time_payments u0)
    (if (< total_loans u5)
      (/ (* on_time_payments u700) (+ total_loans u5)) 
      (/ (* on_time_payments u700) total_loans)
    )
    u0
  )
)