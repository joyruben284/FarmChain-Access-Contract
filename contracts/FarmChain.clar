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


;; Add new map
(define-map farm-certifications
    { farm-id: uint }
    {
        organic: bool,
        fair-trade: bool,
        certification-date: uint,
        certifier: principal
    }
)

(define-public (add-certification (farm-id uint) (cert-type (string-ascii 20)))
    (let
        ((farm (unwrap! (get-farm-data farm-id) err-invalid-data)))
        (try! (is-authorized))
        (map-set farm-certifications
            { farm-id: farm-id }
            {
                organic: true,
                fair-trade: true,
                certification-date: stacks-block-height,
                certifier: tx-sender
            }
        )
        (ok true)
    )
)


(define-map harvests
    { harvest-id: uint }
    {
        crop-id: uint,
        quantity: uint,
        harvest-date: uint,
        quality-grade: (string-ascii 2)
    }
)

(define-data-var last-harvest-id uint u0)

(define-public (record-harvest (crop-id uint) (quantity uint) (quality-grade (string-ascii 2)))
    (let
        (
            (new-harvest-id (+ (var-get last-harvest-id) u1))
            (crop (unwrap! (get-crop-data crop-id) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set harvests
            { harvest-id: new-harvest-id }
            {
                crop-id: crop-id,
                quantity: quantity,
                harvest-date: stacks-block-height,
                quality-grade: quality-grade
            }
        )
        (var-set last-harvest-id new-harvest-id)
        (ok new-harvest-id)
    )
)


(define-map weather-events
    { event-id: uint }
    {
        farm-id: uint,
        event-type: (string-ascii 20),
        severity: uint,
        date: uint
    }
)

(define-data-var last-weather-event-id uint u0)

(define-public (record-weather-event (farm-id uint) (event-type (string-ascii 20)) (severity uint))
    (let
        ((new-event-id (+ (var-get last-weather-event-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set weather-events
            { event-id: new-event-id }
            {
                farm-id: farm-id,
                event-type: event-type,
                severity: severity,
                date: stacks-block-height
            }
        )
        (var-set last-weather-event-id new-event-id)
        (ok new-event-id)
    )
)



(define-map farm-workers
    { worker-id: uint }
    {
        farm-id: uint,
        worker-address: principal,
        role: (string-ascii 20),
        active: bool
    }
)

(define-data-var last-worker-id uint u0)

(define-public (add-farm-worker (farm-id uint) (worker-address principal) (role (string-ascii 20)))
    (let
        ((new-worker-id (+ (var-get last-worker-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set farm-workers
            { worker-id: new-worker-id }
            {
                farm-id: farm-id,
                worker-address: worker-address,
                role: role,
                active: true
            }
        )
        (var-set last-worker-id new-worker-id)
        (ok new-worker-id)
    )
)



(define-map equipment
    { equipment-id: uint }
    {
        farm-id: uint,
        name: (string-ascii 50),
        purchase-date: uint,
        status: (string-ascii 20)
    }
)

(define-data-var last-equipment-id uint u0)

(define-public (register-equipment (farm-id uint) (name (string-ascii 50)))
    (let
        ((new-equipment-id (+ (var-get last-equipment-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set equipment
            { equipment-id: new-equipment-id }
            {
                farm-id: farm-id,
                name: name,
                purchase-date: stacks-block-height,
                status: "active"
            }
        )
        (var-set last-equipment-id new-equipment-id)
        (ok new-equipment-id)
    )
)


(define-map disease-reports
    { report-id: uint }
    {
        crop-id: uint,
        disease-name: (string-ascii 50),
        severity: uint,
        detection-date: uint
    }
)

(define-data-var last-report-id uint u0)

(define-public (report-disease (crop-id uint) (disease-name (string-ascii 50)) (severity uint))
    (let
        (
            (new-report-id (+ (var-get last-report-id) u1))
            (crop (unwrap! (get-crop-data crop-id) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set disease-reports
            { report-id: new-report-id }
            {
                crop-id: crop-id,
                disease-name: disease-name,
                severity: severity,
                detection-date: stacks-block-height
            }
        )
        (var-set last-report-id new-report-id)
        (ok new-report-id)
    )
)


(define-map resource-usage
    { usage-id: uint }
    {
        farm-id: uint,
        resource-type: (string-ascii 20),
        quantity: uint,
        date: uint
    }
)

(define-data-var last-usage-id uint u0)

(define-public (track-resource-usage (farm-id uint) (resource-type (string-ascii 20)) (quantity uint))
    (let
        ((new-usage-id (+ (var-get last-usage-id) u1)))
        (try! (is-farm-owner farm-id))
        (map-set resource-usage
            { usage-id: new-usage-id }
            {
                farm-id: farm-id,
                resource-type: resource-type,
                quantity: quantity,
                date: stacks-block-height
            }
        )
        (var-set last-usage-id new-usage-id)
        (ok new-usage-id)
    )
)


(define-map crop-insurance
    { policy-id: uint }
    {
        crop-id: uint,
        coverage-amount: uint,
        start-date: uint,
        end-date: uint,
        active: bool
    }
)

(define-data-var last-policy-id uint u0)

(define-public (create-insurance-policy (crop-id uint) (coverage-amount uint) (duration uint))
    (let
        (
            (new-policy-id (+ (var-get last-policy-id) u1))
            (crop (unwrap! (get-crop-data crop-id) err-invalid-data))
        )
        (try! (is-farm-owner (get farm-id crop)))
        (map-set crop-insurance
            { policy-id: new-policy-id }
            {
                crop-id: crop-id,
                coverage-amount: coverage-amount,
                start-date: stacks-block-height,
                end-date: (+ stacks-block-height duration),
                active: true
            }
        )
        (var-set last-policy-id new-policy-id)
        (ok new-policy-id)
    )
)
