;; title: Truthdrop
;; version: 1.0.0
;; summary: Journalism NFT Fund - Back credible, verified reporters
;; description: A decentralized platform for funding and verifying independent journalists through NFTs

(define-non-fungible-token journalist-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-journalist-not-verified (err u106))
(define-constant err-funding-closed (err u107))

(define-data-var next-journalist-id uint u1)
(define-data-var platform-fee uint u500)
(define-data-var min-verification-stake uint u1000000)

(define-map journalists
  uint
  {
    owner: principal,
    name: (string-ascii 64),
    bio: (string-ascii 256),
    verification-stake: uint,
    total-funded: uint,
    verified: bool,
    created-at: uint,
    active: bool
  }
)

(define-map journalist-metrics
  uint
  {
    articles-published: uint,
    backers-count: uint,
    credibility-score: uint,
    last-activity: uint
  }
)

(define-map funding-campaigns
  uint
  {
    journalist-id: uint,
    title: (string-ascii 128),
    description: (string-ascii 512),
    target-amount: uint,
    current-amount: uint,
    end-block: uint,
    created-by: principal,
    active: bool
  }
)

(define-map campaign-backers
  {campaign-id: uint, backer: principal}
  {amount: uint, backed-at: uint}
)

(define-map journalist-backers
  {journalist-id: uint, backer: principal}
  {total-backed: uint, first-backed: uint, last-backed: uint}
)

(define-map verifiers
  principal
  {authorized: bool, verified-count: uint}
)

(define-data-var next-campaign-id uint u1)

(define-read-only (get-last-token-id)
  (ok (- (var-get next-journalist-id) u1))
)

(define-read-only (get-token-uri (token-id uint))
  (ok none)
)

(define-read-only (get-owner (token-id uint))
  (ok (get owner (map-get? journalists token-id)))
)

(define-read-only (transfer (token-id uint) (sender principal) (recipient principal))
  (ok false)
)

(define-public (register-journalist (name (string-ascii 64)) (bio (string-ascii 256)))
  (let
    (
      (journalist-id (var-get next-journalist-id))
      (stake-amount (var-get min-verification-stake))
    )
    (asserts! (>= (stx-get-balance tx-sender) stake-amount) err-insufficient-funds)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    (try! (nft-mint? journalist-nft journalist-id tx-sender))
    (map-set journalists journalist-id
      {
        owner: tx-sender,
        name: name,
        bio: bio,
        verification-stake: stake-amount,
        total-funded: u0,
        verified: false,
        created-at: stacks-block-height,
        active: true
      }
    )
    (map-set journalist-metrics journalist-id
      {
        articles-published: u0,
        backers-count: u0,
        credibility-score: u50,
        last-activity: stacks-block-height
      }
    )
    (var-set next-journalist-id (+ journalist-id u1))
    (ok journalist-id)
  )
)

(define-public (verify-journalist (journalist-id uint))
  (let
    (
      (journalist (unwrap! (map-get? journalists journalist-id) err-not-found))
      (verifier-info (default-to {authorized: false, verified-count: u0} (map-get? verifiers tx-sender)))
    )
    (asserts! (or (is-eq tx-sender contract-owner) (get authorized verifier-info)) err-unauthorized)
    (asserts! (get active journalist) err-not-found)
    (map-set journalists journalist-id
      (merge journalist {verified: true})
    )
    (map-set verifiers tx-sender
      (merge verifier-info {verified-count: (+ (get verified-count verifier-info) u1)})
    )
    (ok true)
  )
)

(define-public (create-funding-campaign 
  (journalist-id uint) 
  (title (string-ascii 128)) 
  (description (string-ascii 512)) 
  (target-amount uint) 
  (duration-blocks uint))
  (let
    (
      (journalist (unwrap! (map-get? journalists journalist-id) err-not-found))
      (campaign-id (var-get next-campaign-id))
    )
    (asserts! (is-eq tx-sender (get owner journalist)) err-unauthorized)
    (asserts! (get verified journalist) err-journalist-not-verified)
    (asserts! (get active journalist) err-not-found)
    (asserts! (> target-amount u0) err-invalid-amount)
    (map-set funding-campaigns campaign-id
      {
        journalist-id: journalist-id,
        title: title,
        description: description,
        target-amount: target-amount,
        current-amount: u0,
        end-block: (+ stacks-block-height duration-blocks),
        created-by: tx-sender,
        active: true
      }
    )
    (var-set next-campaign-id (+ campaign-id u1))
    (ok campaign-id)
  )
)

(define-public (back-campaign (campaign-id uint) (amount uint))
  (let
    (
      (campaign (unwrap! (map-get? funding-campaigns campaign-id) err-not-found))
      (journalist-id (get journalist-id campaign))
      (journalist (unwrap! (map-get? journalists journalist-id) err-not-found))
      (platform-fee-amount (/ (* amount (var-get platform-fee)) u10000))
      (net-amount (- amount platform-fee-amount))
      (existing-backing (default-to {amount: u0, backed-at: u0} 
        (map-get? campaign-backers {campaign-id: campaign-id, backer: tx-sender})))
      (existing-journalist-backing (default-to {total-backed: u0, first-backed: u0, last-backed: u0}
        (map-get? journalist-backers {journalist-id: journalist-id, backer: tx-sender})))
    )
    (asserts! (get active campaign) err-funding-closed)
    (asserts! (<= stacks-block-height (get end-block campaign)) err-funding-closed)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= (stx-get-balance tx-sender) amount) err-insufficient-funds)
    
    (try! (stx-transfer? net-amount tx-sender (get owner journalist)))
    (try! (stx-transfer? platform-fee-amount tx-sender contract-owner))
    
    (map-set campaign-backers {campaign-id: campaign-id, backer: tx-sender}
      {
        amount: (+ (get amount existing-backing) amount),
        backed-at: stacks-block-height
      }
    )
    
    (map-set journalist-backers {journalist-id: journalist-id, backer: tx-sender}
      {
        total-backed: (+ (get total-backed existing-journalist-backing) amount),
        first-backed: (if (is-eq (get first-backed existing-journalist-backing) u0) 
          stacks-block-height 
          (get first-backed existing-journalist-backing)),
        last-backed: stacks-block-height
      }
    )
    
    (map-set funding-campaigns campaign-id
      (merge campaign {current-amount: (+ (get current-amount campaign) amount)})
    )
    
    (map-set journalists journalist-id
      (merge journalist {total-funded: (+ (get total-funded journalist) amount)})
    )
    
    (let ((metrics (unwrap! (map-get? journalist-metrics journalist-id) err-not-found)))
      (if (is-eq (get amount existing-backing) u0)
        (map-set journalist-metrics journalist-id
          (merge metrics {backers-count: (+ (get backers-count metrics) u1)}))
        true
      )
    )
    
    (ok true)
  )
)

(define-public (update-journalist-activity (journalist-id uint) (articles-count uint))
  (let
    (
      (journalist (unwrap! (map-get? journalists journalist-id) err-not-found))
      (metrics (unwrap! (map-get? journalist-metrics journalist-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner journalist)) err-unauthorized)
    (asserts! (get verified journalist) err-journalist-not-verified)
    (map-set journalist-metrics journalist-id
      (merge metrics 
        {
          articles-published: (+ (get articles-published metrics) articles-count),
          last-activity: stacks-block-height,
          credibility-score: (if (< (+ (get credibility-score metrics) (* articles-count u2)) u100)
            (+ (get credibility-score metrics) (* articles-count u2))
            u100)
        }
      )
    )
    (ok true)
  )
)

(define-public (close-campaign (campaign-id uint))
  (let
    (
      (campaign (unwrap! (map-get? funding-campaigns campaign-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get created-by campaign)) err-unauthorized)
    (map-set funding-campaigns campaign-id
      (merge campaign {active: false})
    )
    (ok true)
  )
)

(define-public (authorize-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set verifiers verifier {authorized: true, verified-count: u0})
    (ok true)
  )
)

(define-public (revoke-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set verifiers verifier {authorized: false, verified-count: u0})
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-amount)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (set-min-verification-stake (new-stake uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-verification-stake new-stake)
    (ok true)
  )
)

(define-public (deactivate-journalist (journalist-id uint))
  (let
    (
      (journalist (unwrap! (map-get? journalists journalist-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner journalist)) err-unauthorized)
    (map-set journalists journalist-id
      (merge journalist {active: false})
    )
    (ok true)
  )
)

(define-read-only (get-journalist (journalist-id uint))
  (map-get? journalists journalist-id)
)

(define-read-only (get-journalist-metrics (journalist-id uint))
  (map-get? journalist-metrics journalist-id)
)

(define-read-only (get-campaign (campaign-id uint))
  (map-get? funding-campaigns campaign-id)
)

(define-read-only (get-campaign-backing (campaign-id uint) (backer principal))
  (map-get? campaign-backers {campaign-id: campaign-id, backer: backer})
)

(define-read-only (get-journalist-backing (journalist-id uint) (backer principal))
  (map-get? journalist-backers {journalist-id: journalist-id, backer: backer})
)

(define-read-only (get-verifier-status (verifier principal))
  (map-get? verifiers verifier)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-read-only (get-min-verification-stake)
  (var-get min-verification-stake)
)

(define-read-only (is-campaign-active (campaign-id uint))
  (match (map-get? funding-campaigns campaign-id)
    campaign (and (get active campaign) (<= stacks-block-height (get end-block campaign)))
    false
  )
)

(define-read-only (get-journalist-reputation (journalist-id uint))
  (match (map-get? journalist-metrics journalist-id)
    metrics 
      {
        credibility-score: (get credibility-score metrics),
        articles-published: (get articles-published metrics),
        activity-score: (if (> (- stacks-block-height (get last-activity metrics)) u1000) u0 u25),
        total-score: (+ (get credibility-score metrics) 
          (if (> (- stacks-block-height (get last-activity metrics)) u1000) u0 u25))
      }
    {credibility-score: u0, articles-published: u0, activity-score: u0, total-score: u0}
  )
)

(define-read-only (get-campaign-progress (campaign-id uint))
  (match (map-get? funding-campaigns campaign-id)
    campaign 
      {
        percentage: (/ (* (get current-amount campaign) u100) (get target-amount campaign)),
        remaining: (- (get target-amount campaign) (get current-amount campaign)),
        blocks-remaining: (if (<= stacks-block-height (get end-block campaign))
          (- (get end-block campaign) stacks-block-height)
          u0)
      }
    {percentage: u0, remaining: u0, blocks-remaining: u0}
  )
)

(define-private (is-journalist-owner (journalist-id uint) (user principal))
  (match (map-get? journalists journalist-id)
    journalist (is-eq user (get owner journalist))
    false
  )
)

(define-private (calculate-reputation-bonus (journalist-id uint))
  (let
    (
      (reputation (get-journalist-reputation journalist-id))
    )
    (/ (get total-score reputation) u10)
  )
)
