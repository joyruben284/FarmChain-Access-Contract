;; FarmChain Access - Agricultural Supply Chain Verification
;; Core functionality for crop tracking and farm data

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-invalid-data (err u101))

;; Data Maps
(define-map farms 
    { farm-id: uint }
    {
        owner: principal,
        name: (string-ascii 50),
        location: (string-ascii 100),
        active: bool
    }
)

(define-map crops
    { crop-id: uint }
    {
        farm-id: uint,
        crop-type: (string-ascii 50),
        planting-date: uint,
        expected-yield: uint,
        status: (string-ascii 20)
    }
)

;; Data Variables
(define-data-var last-farm-id uint u0)
(define-data-var last-crop-id uint u0)

;; Public Functions
(define-public (register-farm (name (string-ascii 50)) (location (string-ascii 100)))
    (let
        (
            (new-farm-id (+ (var-get last-farm-id) u1))
        )
        (try! (is-authorized))
        (map-set farms
            { farm-id: new-farm-id }
            {
                owner: tx-sender,
                name: name,
                location: location,
                active: true
            }
        )
        (var-set last-farm-id new-farm-id)
        (ok new-farm-id)
    )
)

(define-public (add-crop 
        (farm-id uint) 
        (crop-type (string-ascii 50)) 
        (expected-yield uint)
    )
    (let
        (
            (new-crop-id (+ (var-get last-crop-id) u1))
        )
        (try! (is-farm-owner farm-id))
        (map-set crops
            { crop-id: new-crop-id }
            {
                farm-id: farm-id,
                crop-type: crop-type,
                planting-date: stacks-block-height,
                expected-yield: expected-yield,
                status: "active"
            }
        )
        (var-set last-crop-id new-crop-id)
        (ok new-crop-id)
    )
)

(define-public (update-crop-status (crop-id uint) (new-status (string-ascii 20)))
    (let
        (
            (crop (unwrap! (get-crop-data crop-id) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set crops
            { crop-id: crop-id }
            (merge crop { status: new-status })
        )
        (ok true)
    )
)

;; Read-only Functions
(define-read-only (get-farm-data (farm-id uint))
    (map-get? farms { farm-id: farm-id })
)

(define-read-only (get-crop-data (crop-id uint))
    (map-get? crops { crop-id: crop-id })
)

;; Private Functions
(define-private (is-authorized)
    (if (is-eq tx-sender contract-owner)
        (ok true)
        err-not-authorized
    )
)

(define-private (is-farm-owner (farm-id uint))
    (let
        (
            (farm (unwrap! (get-farm-data farm-id) err-invalid-data))
        )
        (if (is-eq (get owner farm) tx-sender)
            (ok true)
            err-not-authorized
    )
)
)
