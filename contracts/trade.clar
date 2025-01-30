;; Define the contract
(define-non-fungible-token carbon-credit uint)

;; Define data structures
(define-data-var total-supply uint u0)
(define-map balances principal uint)
(define-map expiration-dates uint uint)
(define-map auctions uint { seller: principal, min-bid: uint, highest-bid: uint, highest-bidder: principal })
(define-map credit-metadata uint { issuer: (string-ascii 50), project-id: (string-ascii 50), vintage-year: uint })

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_BATCH_SIZE u50)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_TOKEN (err u102))
(define-constant ERR_EXPIRED_TOKEN (err u103))
(define-constant ERR_AUCTION_NOT_FOUND (err u104))
(define-constant ERR_INVALID_BID (err u105))
(define-constant ERR_AUCTION_CLOSED (err u106))
(define-constant ERR_INVALID_INPUT (err u107))
(define-constant ERR_INVALID_RECIPIENT (err u108))

;; Helper function to validate principal
(define-private (validate-principal (user principal))
  (if (is-some (some user))
      (ok user)
      ERR_INVALID_RECIPIENT))

;; Helper function to validate and format string input
(define-private (validate-and-format-string (input (string-ascii 50)))
  (match (as-max-len? input u50)
    success (ok success)
    ERR_INVALID_INPUT))

;; Mint new carbon credits (only contract owner can mint)
(define-public (mint-carbon-credit (recipient principal) (amount uint) (expiration uint) 
    (issuer (string-ascii 50)) (project-id (string-ascii 50)) (vintage-year uint))
  (begin
    ;; Basic validations
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (and (> amount u0) (<= amount MAX_BATCH_SIZE)) ERR_INVALID_INPUT)
    (asserts! (> expiration block-height) ERR_INVALID_INPUT)
    (asserts! (<= vintage-year (/ block-height u144)) ERR_INVALID_INPUT)
    
    ;; Validate recipient
    (try! (validate-principal recipient))
    
    ;; String validations
    (let 
      ((valid-issuer (try! (validate-and-format-string issuer)))
       (valid-project-id (try! (validate-and-format-string project-id)))
       (recipient-balance (default-to u0 (map-get? balances recipient)))
       (new-balance (+ recipient-balance amount)))
      
      ;; Additional validations
      (asserts! (<= new-balance (- (pow u2 u128) u1)) ERR_INVALID_INPUT)
      
      ;; Perform operations
      (try! (as-contract (nft-mint? carbon-credit amount recipient)))
      (var-set total-supply (+ (var-get total-supply) amount))
      (map-set balances recipient new-balance)
      (map-set expiration-dates amount expiration)
      (map-set credit-metadata amount {
        issuer: valid-issuer,
        project-id: valid-project-id,
        vintage-year: vintage-year
      })
      (ok amount)
    )
  ))

;; Transfer carbon credits between users
(define-public (transfer-carbon-credit (sender principal) (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    (asserts! (not (is-eq sender recipient)) ERR_INVALID_INPUT)
    
    ;; Validate both principals
    (try! (validate-principal sender))
    (try! (validate-principal recipient))
    
    (let ((sender-balance (default-to u0 (map-get? balances sender)))
          (recipient-balance (default-to u0 (map-get? balances recipient))))
      (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
      (let ((expiration (unwrap! (map-get? expiration-dates amount) ERR_INVALID_TOKEN)))
        (asserts! (> expiration block-height) ERR_EXPIRED_TOKEN)
        (try! (nft-transfer? carbon-credit amount sender recipient))
        (map-set balances sender (- sender-balance amount))
        (map-set balances recipient (+ recipient-balance amount))
        (ok amount)
      )
    )
  )
)

;; Cancel auction (only seller can cancel if no bids)
(define-public (cancel-auction (token-id uint))
  (let ((auction (unwrap! (map-get? auctions token-id) ERR_AUCTION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get seller auction)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get highest-bid auction) u0) ERR_AUCTION_CLOSED)
    (map-delete auctions token-id)
    (ok token-id)
  )
)

;; Verify carbon credit authenticity and metadata
(define-read-only (verify-credit (token-id uint))
  (let ((metadata (unwrap! (map-get? credit-metadata token-id) ERR_INVALID_TOKEN))
        (expiration (unwrap! (map-get? expiration-dates token-id) ERR_INVALID_TOKEN))
        (owner (unwrap! (nft-get-owner? carbon-credit token-id) ERR_INVALID_TOKEN)))
    (ok {
      owner: owner,
      issuer: (get issuer metadata),
      project-id: (get project-id metadata),
      vintage-year: (get vintage-year metadata),
      expiration: expiration,
      is-expired: (<= expiration block-height),
      is-valid: (and (> expiration block-height) 
                    (is-some (nft-get-owner? carbon-credit token-id)))
    })
  )
)

;; Retire carbon credits (remove from circulation)
(define-public (retire-carbon-credit (owner principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    
    ;; Validate owner
    (try! (validate-principal owner))
    
    (let ((owner-balance (default-to u0 (map-get? balances owner))))
      (asserts! (>= owner-balance amount) ERR_INSUFFICIENT_BALANCE)
      (try! (as-contract (nft-burn? carbon-credit amount owner)))
      (map-set balances owner (- owner-balance amount))
      (var-set total-supply (- (var-get total-supply) amount))
      (ok amount)
    )
  )
)

;; List carbon credit for auction
(define-public (list-for-auction (seller principal) (token-id uint) (min-bid uint))
  (begin
    (asserts! (is-eq tx-sender seller) ERR_UNAUTHORIZED)
    (asserts! (is-some (nft-get-owner? carbon-credit token-id)) ERR_INVALID_TOKEN)
    (asserts! (is-eq (unwrap! (nft-get-owner? carbon-credit token-id) ERR_INVALID_TOKEN) seller) ERR_UNAUTHORIZED)
    (asserts! (> min-bid u0) ERR_INVALID_INPUT)
    
    ;; Validate seller
    (try! (validate-principal seller))
    
    (let ((expiration (unwrap! (map-get? expiration-dates token-id) ERR_INVALID_TOKEN)))
      (asserts! (> expiration block-height) ERR_EXPIRED_TOKEN)
      (map-set auctions token-id { seller: seller, min-bid: min-bid, highest-bid: u0, highest-bidder: seller })
      (ok token-id)
    )
  )
)

;; Bid on a carbon credit auction
(define-public (bid-on-auction (bidder principal) (token-id uint) (bid-amount uint))
  (begin
    ;; Validate bidder
    (try! (validate-principal bidder))
    
    (let ((auction (unwrap! (map-get? auctions token-id) ERR_AUCTION_NOT_FOUND)))
      (asserts! (not (is-eq bidder (get seller auction))) ERR_INVALID_BID)
      (asserts! (> bid-amount (get highest-bid auction)) ERR_INVALID_BID)
      (asserts! (>= bid-amount (get min-bid auction)) ERR_INVALID_BID)
      (map-set auctions token-id 
        (merge auction { highest-bid: bid-amount, highest-bidder: bidder }))
      (ok token-id)
    )
  )
)

;; Finalize auction and transfer carbon credit to the highest bidder
(define-public (finalize-auction (token-id uint))
  (let ((auction (unwrap! (map-get? auctions token-id) ERR_AUCTION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get seller auction)) ERR_UNAUTHORIZED)
    (asserts! (> (get highest-bid auction) u0) ERR_AUCTION_CLOSED)
    (try! (as-contract (nft-transfer? carbon-credit token-id 
                         (get seller auction) 
                         (get highest-bidder auction))))
    (map-delete auctions token-id)
    (ok token-id)
  )
)

;; Get total supply of carbon credits
(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

;; Get balance of a specific user
(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? balances user)))
)

;; Get owner of a specific carbon credit NFT
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? carbon-credit token-id))
)

;; Get expiration date of a specific carbon credit NFT
(define-read-only (get-expiration (token-id uint))
  (ok (map-get? expiration-dates token-id))
)

;; Get auction details for a specific carbon credit NFT
(define-read-only (get-auction (token-id uint))
  (ok (map-get? auctions token-id))
)