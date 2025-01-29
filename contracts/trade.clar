;; Define the contract
(define-non-fungible-token carbon-credit uint)

;; Define data structures
(define-data-var total-supply uint u0)
(define-map balances principal uint)

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)

;; Mint new carbon credits (only contract owner can mint)
(define-public (mint-carbon-credit (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) (err u100)) ;; Only owner can mint
    (try! (nft-mint? carbon-credit amount recipient)) ;; Mint NFT and handle response
    (var-set total-supply (+ (var-get total-supply) amount)) ;; Update total supply
    (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount)) ;; Update recipient balance
    (ok amount)
  )
)

;; Transfer carbon credits between users
(define-public (transfer-carbon-credit (sender principal) (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender sender) (err u101)) ;; Only sender can initiate transfer
    (asserts! (>= (default-to u0 (map-get? balances sender)) amount) (err u102)) ;; Check sender balance
    (try! (nft-transfer? carbon-credit amount sender recipient)) ;; Transfer NFT and handle response
    (map-set balances sender (- (default-to u0 (map-get? balances sender)) amount)) ;; Deduct from sender
    (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount)) ;; Add to recipient
    (ok amount)
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