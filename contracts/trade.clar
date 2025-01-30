;; Define the contract
(define-non-fungible-token carbon-credit uint)

;; Define data structures
(define-data-var total-supply uint u0)
(define-map balances principal uint)
(define-map expiration-dates uint uint) ;; Maps token ID to expiration date (block height)
(define-map auctions uint { seller: principal, min-bid: uint, highest-bid: uint, highest-bidder: principal }) ;; Maps token ID to auction details

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)

;; Mint new carbon credits (only contract owner can mint)
(define-public (mint-carbon-credit (recipient principal) (amount uint) (expiration uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u100)) ;; Only owner can mint
    (try! (nft-mint? carbon-credit amount recipient)) ;; Mint NFT and handle response
    (var-set total-supply (+ (var-get total-supply) amount)) ;; Update total supply
    (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount)) ;; Update recipient balance
    (map-set expiration-dates amount expiration) ;; Set expiration date for the minted tokens
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