;; Define the contract
(define-non-fungible-token carbon-credit uint)

;; Define data structures
(define-data-var total-supply uint u0)
(define-map balances principal uint)
(define-map expiration-dates uint uint) ;; Maps token ID to expiration date (block height)
(define-map auctions uint { seller: principal, min-bid: uint, highest-bid: uint, highest-bidder: principal }) ;; Maps token ID to auction details
(define-map credit-metadata uint { issuer: (string-ascii 50), project-id: (string-ascii 50), vintage-year: uint }) ;; Store metadata for verification

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant MAX_BATCH_SIZE u50) ;; Maximum number of transfers in a batch

;; Mint new carbon credits (only contract owner can mint)
(define-public (mint-carbon-credit (recipient principal) (amount uint) (expiration uint) 
    (issuer (string-ascii 50)) (project-id (string-ascii 50)) (vintage-year uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u100)) ;; Only owner can mint
    (try! (nft-mint? carbon-credit amount recipient)) ;; Mint NFT and handle response
    (var-set total-supply (+ (var-get total-supply) amount)) ;; Update total supply
    (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount)) ;; Update recipient balance
    (map-set expiration-dates amount expiration) ;; Set expiration date for the minted tokens
    (map-set credit-metadata amount { issuer: issuer, project-id: project-id, vintage-year: vintage-year }) ;; Store verification metadata
    (ok amount)
  )
)

;; Transfer carbon credits between users
(define-public (transfer-carbon-credit (sender principal) (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender sender) (err u101)) ;; Only sender can initiate transfer
    (asserts! (>= (default-to u0 (map-get? balances sender)) amount) (err u102)) ;; Check sender balance
    (let ((expiration (unwrap! (map-get? expiration-dates amount) (err u103)))) ;; Get expiration date
      (asserts! (> expiration block-height) (err u103)) ;; Check if token is expired
      (try! (nft-transfer? carbon-credit amount sender recipient)) ;; Transfer NFT and handle response
      (map-set balances sender (- (default-to u0 (map-get? balances sender)) amount)) ;; Deduct from sender
      (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount)) ;; Add to recipient
      (ok amount)
    )
  )
)

;; NEW FUNCTIONALITY 1: Batch transfer carbon credits
(define-public (batch-transfer-carbon-credits (sender principal) 
    (recipients (list 50 principal)) (amounts (list 50 uint)))
  (begin
    (asserts! (is-eq tx-sender sender) (err u101)) ;; Only sender can initiate transfer
    (asserts! (is-eq (len recipients) (len amounts)) (err u120)) ;; Lists must be same length
    (asserts! (<= (len recipients) MAX_BATCH_SIZE) (err u121)) ;; Check batch size limit
    
    ;; Calculate total amount being transferred
    (let ((total-amount (fold + amounts u0)))
      ;; Check if sender has enough balance
      (asserts! (>= (default-to u0 (map-get? balances sender)) total-amount) (err u102))
      
      ;; Perform transfers
      (map transfer-helper (zip recipients amounts))
      (ok true)
    )
  )
)

;; Helper function for batch transfers
(define-private (transfer-helper (transfer {recipient: principal, amount: uint}))
  (begin
    (try! (transfer-carbon-credit tx-sender (get recipient transfer) (get amount transfer)))
    (ok true)
  )
)

;; NEW FUNCTIONALITY 2: Cancel auction (only seller can cancel if no bids)
(define-public (cancel-auction (token-id uint))
  (begin
    (let ((auction (unwrap! (map-get? auctions token-id) (err u107)))) ;; Get auction details
      (let ((seller (get seller auction)))
        (let ((highest-bid (get highest-bid auction)))
          (asserts! (is-eq tx-sender seller) (err u110)) ;; Only seller can cancel
          (asserts! (is-eq highest-bid u0) (err u130)) ;; Can only cancel if no bids
          (map-delete auctions token-id)
          (ok token-id)
        )
      )
    )
  )
)

;; NEW FUNCTIONALITY 3: Verify carbon credit authenticity and metadata
(define-public (verify-credit (token-id uint))
  (begin
    (let ((metadata (unwrap! (map-get? credit-metadata token-id) (err u140)))) ;; Get metadata
      (let ((expiration (unwrap! (map-get? expiration-dates token-id) (err u103)))) ;; Get expiration
        (let ((owner (unwrap! (nft-get-owner? carbon-credit token-id) (err u141)))) ;; Get current owner
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
    )
  )
)

;; Retire carbon credits (remove from circulation)
(define-public (retire-carbon-credit (owner principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender owner) (err u104)) ;; Only owner can retire
    (asserts! (>= (default-to u0 (map-get? balances owner)) amount) (err u102)) ;; Check owner balance
    (try! (nft-burn? carbon-credit amount owner)) ;; Burn NFT and handle response
    (map-set balances owner (- (default-to u0 (map-get? balances owner)) amount)) ;; Deduct from owner
    (var-set total-supply (- (var-get total-supply) amount)) ;; Reduce total supply
    (ok amount)
  )
)

;; List carbon credit for auction
(define-public (list-for-auction (seller principal) (token-id uint) (min-bid uint))
  (begin
    (asserts! (is-eq tx-sender seller) (err u105)) ;; Only seller can list
    (asserts! (is-eq (nft-get-owner? carbon-credit token-id) (some seller)) (err u106)) ;; Seller must own the token
    (let ((expiration (unwrap! (map-get? expiration-dates token-id) (err u103)))) ;; Get expiration date
      (asserts! (> expiration block-height) (err u103)) ;; Check if token is expired
      (map-set auctions token-id { seller: seller, min-bid: min-bid, highest-bid: u0, highest-bidder: seller }) ;; Create auction
      (ok token-id)
    )
  )
)

;; Bid on a carbon credit auction
(define-public (bid-on-auction (bidder principal) (token-id uint) (bid-amount uint))
  (begin
    (let ((auction (unwrap! (map-get? auctions token-id) (err u107)))) ;; Get auction details
      (let ((highest-bid (get highest-bid auction))) ;; Get highest bid
        (let ((min-bid (get min-bid auction))) ;; Get minimum bid
          (asserts! (> bid-amount highest-bid) (err u108)) ;; Bid must be higher than current highest bid
          (asserts! (>= bid-amount min-bid) (err u109)) ;; Bid must meet minimum bid
          (map-set auctions token-id { seller: (get seller auction), min-bid: min-bid, highest-bid: bid-amount, highest-bidder: bidder }) ;; Update auction
          (ok token-id)
        )
      )
    )
  )
)

;; Finalize auction and transfer carbon credit to the highest bidder
(define-public (finalize-auction (token-id uint))
  (begin
    (let ((auction (unwrap! (map-get? auctions token-id) (err u107)))) ;; Get auction details
      (let ((seller (get seller auction))) ;; Get seller
        (let ((highest-bid (get highest-bid auction))) ;; Get highest bid
          (let ((highest-bidder (get highest-bidder auction))) ;; Get highest bidder
            (asserts! (is-eq tx-sender seller) (err u110)) ;; Only seller can finalize
            (asserts! (> highest-bid u0) (err u111)) ;; Ensure there is a valid bid
            (try! (nft-transfer? carbon-credit token-id seller highest-bidder)) ;; Transfer NFT to highest bidder
            (map-delete auctions token-id) ;; Remove auction using map-delete
            (ok token-id)
          )
        )
      )
    )
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