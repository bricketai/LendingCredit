
;; title: LendingCredit
;; version: 1.0.0
;; summary: Address reputation system for lending protocol creditworthiness assessment
;; description: This contract tracks and manages creditworthiness scores for addresses
;;              participating in lending protocols, including loan history, repayment behavior,
;;              and overall credit metrics.

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SCORE (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-CREDIT-SCORE u300)
(define-constant MAX-CREDIT-SCORE u850)
(define-constant DEFAULT-CREDIT-SCORE u500)

;; Data variables
(define-data-var contract-active bool true)
(define-data-var total-users uint u0)

;; Data maps
;; Main credit profile for each user
(define-map credit-profiles
  principal
  {
    credit-score: uint,
    total-borrowed: uint,
    total-repaid: uint,
    loans-count: uint,
    defaults-count: uint,
    last-updated: uint,
    is-active: bool
  }
)

;; Loan history tracking
(define-map loan-history
  { borrower: principal, loan-id: uint }
  {
    amount: uint,
    repaid-amount: uint,
    due-date: uint,
    status: (string-ascii 20), ;; "active", "repaid", "defaulted"
    created-at: uint
  }
)

;; Authorized lenders who can update credit information
(define-map authorized-lenders principal bool)

;; Credit score adjustments log
(define-map score-adjustments
  { user: principal, adjustment-id: uint }
  {
    old-score: uint,
    new-score: uint,
    reason: (string-ascii 50),
    adjusted-by: principal,
    timestamp: uint
  }
)

;; Counter for generating unique IDs
(define-data-var next-loan-id uint u1)
(define-data-var next-adjustment-id uint u1)

;; Public functions

;; Initialize a new credit profile
(define-public (create-credit-profile)
  (let ((user tx-sender))
    (asserts! (is-eq (var-get contract-active) true) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? credit-profiles user)) ERR-ALREADY-EXISTS)
    (map-set credit-profiles user {
      credit-score: DEFAULT-CREDIT-SCORE,
      total-borrowed: u0,
      total-repaid: u0,
      loans-count: u0,
      defaults-count: u0,
      last-updated: block-height,
      is-active: true
    })
    (var-set total-users (+ (var-get total-users) u1))
    (ok true)
  )
)

;; Record a new loan (only authorized lenders)
(define-public (record-loan (borrower principal) (amount uint) (due-date uint))
  (let (
    (loan-id (var-get next-loan-id))
    (current-profile (unwrap! (map-get? credit-profiles borrower) ERR-USER-NOT-FOUND))
  )
    (asserts! (is-eq (var-get contract-active) true) ERR-NOT-AUTHORIZED)
    (asserts! (default-to false (map-get? authorized-lenders tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> due-date block-height) ERR-INVALID-AMOUNT)

    ;; Record loan in history
    (map-set loan-history
      { borrower: borrower, loan-id: loan-id }
      {
        amount: amount,
        repaid-amount: u0,
        due-date: due-date,
        status: "active",
        created-at: block-height
      }
    )

    ;; Update credit profile
    (map-set credit-profiles borrower (merge current-profile {
      total-borrowed: (+ (get total-borrowed current-profile) amount),
      loans-count: (+ (get loans-count current-profile) u1),
      last-updated: block-height
    }))

    (var-set next-loan-id (+ loan-id u1))
    (ok loan-id)
  )
)

;; Record loan repayment
(define-public (record-repayment (borrower principal) (loan-id uint) (amount uint))
  (let (
    (loan-key { borrower: borrower, loan-id: loan-id })
    (loan-data (unwrap! (map-get? loan-history loan-key) ERR-USER-NOT-FOUND))
    (current-profile (unwrap! (map-get? credit-profiles borrower) ERR-USER-NOT-FOUND))
    (new-repaid-amount (+ (get repaid-amount loan-data) amount))
    (loan-amount (get amount loan-data))
  )
    (asserts! (is-eq (var-get contract-active) true) ERR-NOT-AUTHORIZED)
    (asserts! (default-to false (map-get? authorized-lenders tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= new-repaid-amount loan-amount) ERR-INVALID-AMOUNT)

    ;; Update loan status
    (let ((new-status (if (>= new-repaid-amount loan-amount) "repaid" "active")))
      (map-set loan-history loan-key (merge loan-data {
        repaid-amount: new-repaid-amount,
        status: new-status
      }))
    )

    ;; Update credit profile
    (map-set credit-profiles borrower (merge current-profile {
      total-repaid: (+ (get total-repaid current-profile) amount),
      last-updated: block-height
    }))

    ;; Improve credit score for full repayment
    (if (>= new-repaid-amount loan-amount)
      (begin
        (try! (adjust-credit-score borrower u10 "loan-repaid"))
        u0)
      u0
    )

    (ok true)
  )
)

;; Record loan default
(define-public (record-default (borrower principal) (loan-id uint))
  (let (
    (loan-key { borrower: borrower, loan-id: loan-id })
    (loan-data (unwrap! (map-get? loan-history loan-key) ERR-USER-NOT-FOUND))
    (current-profile (unwrap! (map-get? credit-profiles borrower) ERR-USER-NOT-FOUND))
  )
    (asserts! (is-eq (var-get contract-active) true) ERR-NOT-AUTHORIZED)
    (asserts! (default-to false (map-get? authorized-lenders tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status loan-data) "active") ERR-INVALID-AMOUNT)
    (asserts! (> block-height (get due-date loan-data)) ERR-INVALID-AMOUNT)

    ;; Update loan status
    (map-set loan-history loan-key (merge loan-data {
      status: "defaulted"
    }))

    ;; Update credit profile
    (map-set credit-profiles borrower (merge current-profile {
      defaults-count: (+ (get defaults-count current-profile) u1),
      last-updated: block-height
    }))

    ;; Decrease credit score for default
    (try! (adjust-credit-score borrower u50 "loan-default"))

    (ok true)
  )
)

;; Adjust credit score (internal function called by contract)
(define-private (adjust-credit-score (user principal) (adjustment uint) (reason (string-ascii 50)))
  (let (
    (current-profile (unwrap! (map-get? credit-profiles user) ERR-USER-NOT-FOUND))
    (current-score (get credit-score current-profile))
    (adjustment-id (var-get next-adjustment-id))
    (new-score (if (is-eq reason "loan-default")
                  (if (>= current-score adjustment)
                    (- current-score adjustment)
                    MIN-CREDIT-SCORE)
                  (if (<= (+ current-score adjustment) MAX-CREDIT-SCORE)
                    (+ current-score adjustment)
                    MAX-CREDIT-SCORE)))
  )
    ;; Log the adjustment
    (map-set score-adjustments
      { user: user, adjustment-id: adjustment-id }
      {
        old-score: current-score,
        new-score: new-score,
        reason: reason,
        adjusted-by: CONTRACT-OWNER,
        timestamp: block-height
      }
    )

    ;; Update credit profile
    (map-set credit-profiles user (merge current-profile {
      credit-score: new-score,
      last-updated: block-height
    }))

    (var-set next-adjustment-id (+ adjustment-id u1))
    (ok new-score)
  )
)

;; Admin functions

;; Add authorized lender
(define-public (add-authorized-lender (lender principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-lenders lender true)
    (ok true)
  )
)

;; Remove authorized lender
(define-public (remove-authorized-lender (lender principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-lenders lender)
    (ok true)
  )
)

;; Toggle contract active status
(define-public (toggle-contract-status)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-active (not (var-get contract-active)))
    (ok (var-get contract-active))
  )
)

;; Read-only functions

;; Get credit profile
(define-read-only (get-credit-profile (user principal))
  (map-get? credit-profiles user)
)

;; Get credit score only
(define-read-only (get-credit-score (user principal))
  (match (map-get? credit-profiles user)
    profile (ok (get credit-score profile))
    ERR-USER-NOT-FOUND
  )
)

;; Get loan details
(define-read-only (get-loan-details (borrower principal) (loan-id uint))
  (map-get? loan-history { borrower: borrower, loan-id: loan-id })
)

;; Check if user is creditworthy (score >= 600)
(define-read-only (is-creditworthy (user principal))
  (match (map-get? credit-profiles user)
    profile (>= (get credit-score profile) u600)
    false
  )
)

;; Calculate debt-to-repayment ratio (returns percentage * 100)
(define-read-only (get-debt-ratio (user principal))
  (match (map-get? credit-profiles user)
    profile
      (let ((total-borrowed (get total-borrowed profile))
            (total-repaid (get total-repaid profile)))
        (if (> total-borrowed u0)
          (ok (/ (* total-repaid u10000) total-borrowed))
          (ok u10000))) ;; 100% if no debt
    ERR-USER-NOT-FOUND
  )
)

;; Check if lender is authorized
(define-read-only (is-authorized-lender (lender principal))
  (default-to false (map-get? authorized-lenders lender))
)

;; Get contract stats
(define-read-only (get-contract-stats)
  {
    total-users: (var-get total-users),
    contract-active: (var-get contract-active),
    next-loan-id: (var-get next-loan-id)
  }
)

;; Get score adjustment history
(define-read-only (get-score-adjustment (user principal) (adjustment-id uint))
  (map-get? score-adjustments { user: user, adjustment-id: adjustment-id })
)
