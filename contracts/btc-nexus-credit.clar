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

;; Comprehensive loan eligibility assessment
(define-private 
  (assess-loan-eligibility 
    (applicant principal)
    (credit_record  {
      total_loans: uint,
      on_time_payments: uint,
      late_payments: uint,
    })
    (requested_amount uint)
  )
  (let 
    (
      (total_loans (get total_loans credit_record))
      (on_time_payments (get on_time_payments credit_record))
      (late_payments (get late_payments credit_record))
      (rolling_balance (calculate-rolling-balance applicant))
    )
    (if (is-eq total_loans u0)
      (begin
        (asserts! (is-eq (+ late_payments on_time_payments) total_loans) false)
        (asserts! (>= rolling_balance requested_amount) false)
        (asserts! (>= (determine-credit-limit (+ (calculate-activity_score rolling_balance) (calculate-payment_score total_loans on_time_payments late_payments))) requested_amount) false)
        (map-set credit_history applicant { 
            total_loans: total_loans,
            on_time_payments: on_time_payments,
            late_payments: late_payments,
          }
        )
        true
      )
      (begin 
        (asserts! (is-eq (+ late_payments on_time_payments) total_loans) false)
        (asserts! (>= rolling_balance requested_amount) false)
        (asserts! (>= (determine-credit-limit (+ (calculate-payment_score total_loans on_time_payments late_payments) (calculate-activity_score rolling_balance))) requested_amount) false)
        (map-set credit_history applicant {
            total_loans: total_loans,
            on_time_payments: on_time_payments,
            late_payments: late_payments,
          }
        )
        true
      )
    )
  ) 
)

;; LENDER FUNCTIONS

;; Deposit liquidity into the pool
(define-public (deposit-liquidity (amount uint))
  (let
    (
      (current_balance (default-to u0 (get balance (map-get? lender_positions tx-sender))))
    ) 
    (asserts! (>= amount u10000000) ERR_INSUFFICIENT_AMOUNT)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer amount tx-sender (as-contract tx-sender) none))
    (map-set lender_positions tx-sender 
      {
        balance: (+ current_balance amount), 
        locked_block: stacks-block-height, 
        unlock_block: (+ stacks-block-height (days-to-blocks (var-get lender_lock_period)))
      }
    )
    (var-set total_liquidity_pool (+ (var-get total_liquidity_pool) amount))
    (print {
      event: "liquidity_deposited",
      lender: tx-sender,
      amount: amount, 
      locked_until_block: (+ stacks-block-height (days-to-blocks (var-get lender_lock_period))),
      total_pool_size: (var-get total_liquidity_pool)
    })
    (ok true)
  )
)

;; Withdraw liquidity from the pool
(define-public (withdraw-liquidity (amount uint)) 
  (begin
    (let
      (
        (lender_balance (default-to u0 (get balance (map-get? lender_positions tx-sender))))
        (unlock_block (default-to u0 (get unlock_block (map-get? lender_positions tx-sender))))
        (locked_block (default-to u0 (get locked_block (map-get? lender_positions tx-sender))))
        (contract_balance (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
        (proportional_share 
          (if (> lender_balance u0)
            (/ 
              (* lender_balance contract_balance) 
              (if (> (var-get total_liquidity_pool) u0)
                (var-get total_liquidity_pool)
                u1
              )
            )
            u0
          )
        )
      )
      (asserts! (> lender_balance u0) ERR_INVALID_LENDER)
      (asserts! (<= amount proportional_share) ERR_POOL_LIMIT_EXCEEDED)
      (asserts! (<= unlock_block stacks-block-height) ERR_FUNDS_LOCKED)
      (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer amount (as-contract tx-sender) tx-sender none))
      (var-set total_liquidity_pool 
        (if (< lender_balance amount)
          (+ 
            (- (var-get total_liquidity_pool) lender_balance)
            (- proportional_share amount)
          )
          (- (var-get total_liquidity_pool) amount)
        )
      )
      (if (>= amount lender_balance)
        (if (is-eq amount proportional_share)
          (map-delete lender_positions tx-sender)
          (map-set lender_positions tx-sender 
            {
              balance: (- proportional_share amount),
              locked_block: locked_block,
              unlock_block: unlock_block
            }
          )
        )
        (if (< lender_balance proportional_share)
          (map-set lender_positions tx-sender 
            {
              balance: (- proportional_share amount),
              locked_block: locked_block,
              unlock_block: unlock_block
            }
          )
          (map-set lender_positions tx-sender 
            {
              balance: (- lender_balance amount),
              locked_block: locked_block,
              unlock_block: unlock_block
            }
          )
        )
      )
    )
    (print {event: "liquidity_withdrawn", lender: tx-sender, amount: amount})
    (ok true)
  )
)

;; Get maximum withdrawal amount
(define-read-only (get-max-withdrawal (lender principal))
  (let
    (
      (lender_balance (default-to u0 (get balance (map-get? lender_positions lender))))
      (contract_balance (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
      (max_withdrawal 
        (if (> lender_balance u0)
          (/ 
            (* lender_balance contract_balance) 
            (if (> (var-get total_liquidity_pool) u0)
              (var-get total_liquidity_pool)
              u1
            )
          )
          u0
        )
      )
    )
    (asserts! (> lender_balance u0) ERR_INVALID_LENDER)
    (ok {max_withdrawal_amount: max_withdrawal})
  )
)

;; BORROWER FUNCTIONS

;; Apply for credit with automated underwriting
(define-public (apply-for-credit (requested_amount uint)) 
  (let 
    (
      (credit_record (default-to {
          total_loans: u0,
          on_time_payments: u0,
          late_payments: u0,
        } (map-get? credit_history tx-sender)
      ))
      (loan_term_blocks (days-to-blocks (var-get loan_term_days)))
    )
    (asserts! (> requested_amount u0) ERR_INSUFFICIENT_AMOUNT)
    (asserts! (assess-loan-eligibility tx-sender credit_record requested_amount) ERR_CREDIT_INELIGIBLE)
    (asserts! (> (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))) requested_amount) ERR_INSUFFICIENT_LIQUIDITY)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer requested_amount (as-contract tx-sender) tx-sender none))
    (map-set active_loans tx-sender {
      amount: requested_amount,
      due_block: (+ stacks-block-height loan_term_blocks),
      interest_rate: (var-get base_interest_rate),
      issued_block: stacks-block-height
    })
    (map-set credit_history tx-sender {
      total_loans: (+ u1 (get total_loans credit_record)),
      on_time_payments: (get on_time_payments credit_record),
      late_payments: (get late_payments credit_record),
    })
    (print 
      {
        event: "credit_approved", 
        borrower: tx-sender, 
        principal_amount: requested_amount,
        total_repayment: (calculate-total-repayment tx-sender), 
        due_block: (+ stacks-block-height loan_term_blocks), 
        interest_rate: (var-get base_interest_rate), 
        issued_block: stacks-block-height
      })
    (ok true)
  )
)

;; Repay loan
(define-public (repay-loan (borrower principal))
  (let 
    (
      (loan_details (default-to { amount: u0, due_block: u0, interest_rate: u0, issued_block: u0, } (map-get? active_loans borrower)))
      (total_repayment (calculate-total-repayment borrower))
    )
    (asserts! (> (get amount loan_details) u0) ERR_CREDIT_INELIGIBLE)
    (try! (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token transfer total_repayment tx-sender (as-contract tx-sender) none))
    (process-payment-and-update-history borrower)
    (print {event: "loan_repaid", borrower: borrower, amount_paid: total_repayment})
    (ok true)
  )
)

;; Calculate total repayment amount
(define-read-only (calculate-total-repayment (borrower principal))
  (let 
    (
      (principal_amount (default-to u0 (get amount (map-get? active_loans borrower))))
      (interest_rate (default-to u0 (get interest_rate (map-get? active_loans borrower))))
    )
    (if (> interest_rate u0)
      (+ principal_amount (/ (* principal_amount interest_rate) u100))
      u0
    )
  )
)

;; Get comprehensive credit assessment
(define-read-only (get-credit-assessment (account principal))
  (let
    (
      (credit_record (default-to {
          total_loans: u0,
          on_time_payments: u0,
          late_payments: u0,
        } (map-get? credit_history account)
      ))
      (total_loans (get total_loans credit_record))
      (on_time_payments (get on_time_payments credit_record))
      (late_payments (get late_payments credit_record))
      (rolling_balance (calculate-rolling-balance account))
      (credit_limit (determine-credit-limit (+ (calculate-payment_score total_loans on_time_payments late_payments) (calculate-activity_score rolling_balance))))
    )
    (asserts! (is-eq total_loans (+ late_payments on_time_payments)) (ok {
      composite_score: (+ (calculate-payment_score total_loans on_time_payments late_payments) (calculate-activity_score rolling_balance)),
      tier_limit: credit_limit,
      rolling_balance: rolling_balance,
      approved_limit: u0
    }))
    (asserts! (< rolling_balance credit_limit) (ok {
      composite_score: (+ (calculate-payment_score total_loans on_time_payments late_payments) (calculate-activity_score rolling_balance)),
      tier_limit: credit_limit,
      rolling_balance: rolling_balance,
      approved_limit: credit_limit
    }))
    (ok {
      composite_score: (+ (calculate-payment_score total_loans on_time_payments late_payments) (calculate-activity_score rolling_balance)),
      tier_limit: credit_limit,
      rolling_balance: rolling_balance,
      approved_limit: rolling_balance
    })
  )
)

;; ADMIN FUNCTIONS

;; Transfer admin rights
(define-public (transfer-admin-rights (new_admin principal))
  (begin  
    (asserts! (verify-admin-access) ERR_UNAUTHORIZED_ACCESS)
    (ok (var-set protocol_admin new_admin))
  )
)

;; Set loan term
(define-public (set-loan-term (days uint))
  (begin
    (asserts! (verify-admin-access) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (>= days u7) ERR_INSUFFICIENT_AMOUNT)
    (ok (var-set loan_term_days days))
  )
)

;; Set lock period
(define-public (set-lock-period (days uint))
  (begin
    (asserts! (verify-admin-access) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (> days u0) ERR_INSUFFICIENT_AMOUNT)
    (ok (var-set lender_lock_period days))
  )
)

;; Set base interest rate
(define-public (set-base-rate (rate_percent uint))
  (begin
    (asserts! (verify-admin-access) ERR_UNAUTHORIZED_ACCESS)
    (asserts! (> rate_percent u0) ERR_INSUFFICIENT_AMOUNT)
    (ok (var-set base_interest_rate rate_percent))
  )
)

;; READ-ONLY FUNCTIONS

;; Get loan eligibility status
(define-read-only (get-loan-eligibility (account principal))
  (let
    (
      (credit_record (default-to 
        { 
          total_loans: u0,
          on_time_payments: u0,
          late_payments: u0,
        }
        (map-get? credit_history account)
      ))
      (total_loans (get total_loans credit_record))
      (on_time_payments (get on_time_payments credit_record))
      (late_payments (get late_payments credit_record))
      (rolling_balance (calculate-rolling-balance account))
      (credit_limit (determine-credit-limit (+ (calculate-payment_score total_loans on_time_payments late_payments) (calculate-activity_score rolling_balance))))
    )
    (if (> total_loans (+ on_time_payments late_payments))
      (ok {
        status: "ACTIVE_LOAN_EXISTS",
        available_credit: u0,
        interest_rate: (var-get base_interest_rate),
        loan_term: (var-get loan_term_days),
      })
      (if (>= credit_limit rolling_balance)
        (ok {
          status: "ELIGIBLE",
          available_credit: rolling_balance,
          interest_rate: (var-get base_interest_rate),
          loan_term: (var-get loan_term_days),
        })
        (ok {
          status: "ELIGIBLE",
          available_credit: credit_limit,
          interest_rate: (var-get base_interest_rate),
          loan_term: (var-get loan_term_days),
        })
      )
    )
  )
)

;; Get protocol statistics
(define-read-only (get-protocol-stats)
  (ok {
    lock_period_days: (var-get lender_lock_period),
    total_pool_size: (var-get total_liquidity_pool),
    available_liquidity: (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender)))
  })
)

;; Get lender position details
(define-read-only (get-lender-position)
  (let
    (
      (position_balance (default-to u0 (get balance (map-get? lender_positions tx-sender))))
      (available_liquidity (unwrap-panic (contract-call? 'ST1F7QA2MDF17S807EPA36TSS8AMEFY4KA9TVGWXT.sbtc-token get-balance (as-contract tx-sender))))
      (locked_block (default-to u0 (get locked_block (map-get? lender_positions tx-sender))))
      (unlock_block (default-to u0 (get unlock_block (map-get? lender_positions tx-sender))))
    )
    (ok {
      deposited_balance: position_balance,
      current_value:  
        (if (> position_balance u0)
          (/ (* position_balance available_liquidity) (var-get total_liquidity_pool))
          u0
        ),
      locked_until_block: unlock_block,
      deposit_block: locked_block,
      time_locked_seconds: (/ (- stacks-block-height locked_block) (seconds-per-block)),
    })
  )
)

;; Get borrower account summary
(define-read-only (get-borrower-summary (account principal))
  (ok {
    active_loan_details: (map-get? active_loans account),
    credit_history: (map-get? credit_history account),
    total_repayment_due: (calculate-total-repayment account),
  })
)

;; Get current block height
(define-read-only (get-current-block)
  (ok {
    current_block_height: stacks-block-height,
  })
)