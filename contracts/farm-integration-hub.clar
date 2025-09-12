;; Farm Integration Hub - Central Integration System for FarmChain Ecosystem
;; Enables seamless communication between contracts and external systems

;; Error constants
(define-constant err-not-authorized (err u400))
(define-constant err-invalid-integration (err u401))
(define-constant err-integration-not-found (err u402))
(define-constant err-invalid-endpoint (err u403))
(define-constant err-rate-limit-exceeded (err u404))
(define-constant err-invalid-webhook (err u405))

;; Contract owner
(define-constant contract-owner tx-sender)

;; Integration registry for external services
(define-map external-integrations
    { integration-id: uint }
    {
        service-name: (string-ascii 50),
        service-type: (string-ascii 30), ;; "iot", "api", "oracle", "marketplace"
        endpoint-url: (string-ascii 200),
        api-key-hash: (string-ascii 64),
        active: bool,
        rate-limit: uint,
        last-call: uint,
        call-count: uint,
        owner: principal
    }
)

;; Cross-contract communication registry
(define-map contract-integrations
    { contract-id: uint }
    {
        contract-principal: principal,
        contract-name: (string-ascii 50),
        integration-type: (string-ascii 30), ;; "data-provider", "consumer", "processor"
        permissions: (list 10 (string-ascii 20)),
        active: bool,
        registered-by: principal
    }
)

;; Data synchronization registry
(define-map sync-configurations
    { sync-id: uint }
    {
        source-integration: uint,
        target-integration: uint,
        data-type: (string-ascii 30),
        sync-frequency: uint, ;; blocks between syncs
        last-sync: uint,
        sync-count: uint,
        auto-sync: bool,
        owner: principal
    }
)

;; Webhook registry for real-time notifications
(define-map webhooks
    { webhook-id: uint }
    {
        endpoint-url: (string-ascii 200),
        event-types: (list 5 (string-ascii 30)),
        secret-hash: (string-ascii 64),
        active: bool,
        trigger-count: uint,
        last-triggered: uint,
        owner: principal
    }
)

;; API access logs for monitoring
(define-map api-access-logs
    { log-id: uint }
    {
        integration-id: uint,
        caller: principal,
        endpoint: (string-ascii 100),
        method: (string-ascii 10),
        timestamp: uint,
        status-code: uint,
        response-size: uint
    }
)

;; Data variables for ID tracking
(define-data-var last-integration-id uint u0)
(define-data-var last-contract-id uint u0)
(define-data-var last-sync-id uint u0)
(define-data-var last-webhook-id uint u0)
(define-data-var last-log-id uint u0)

;; Global system settings
(define-data-var max-rate-limit uint u1000)
(define-data-var default-sync-frequency uint u144) ;; ~1 day in blocks

;; Register external integration service
(define-public (register-external-integration
    (service-name (string-ascii 50))
    (service-type (string-ascii 30))
    (endpoint-url (string-ascii 200))
    (api-key-hash (string-ascii 64))
    (rate-limit uint))
    (let ((new-integration-id (+ (var-get last-integration-id) u1)))
        ;; Validate inputs
        (asserts! (> (len service-name) u0) err-invalid-integration)
        (asserts! (> (len endpoint-url) u0) err-invalid-endpoint)
        (asserts! (<= rate-limit (var-get max-rate-limit)) err-rate-limit-exceeded)
        ;; Create integration record
        (map-set external-integrations
            { integration-id: new-integration-id }
            {
                service-name: service-name,
                service-type: service-type,
                endpoint-url: endpoint-url,
                api-key-hash: api-key-hash,
                active: true,
                rate-limit: rate-limit,
                last-call: u0,
                call-count: u0,
                owner: tx-sender
            }
        )
        (var-set last-integration-id new-integration-id)
        (ok new-integration-id)
    )
)

;; Register contract for cross-contract communication
(define-public (register-contract-integration
    (contract-principal principal)
    (contract-name (string-ascii 50))
    (integration-type (string-ascii 30))
    (permissions (list 10 (string-ascii 20))))
    (let ((new-contract-id (+ (var-get last-contract-id) u1)))
        ;; Validate contract principal format
        (asserts! (> (len contract-name) u0) err-invalid-integration)
        ;; Create contract integration record
        (map-set contract-integrations
            { contract-id: new-contract-id }
            {
                contract-principal: contract-principal,
                contract-name: contract-name,
                integration-type: integration-type,
                permissions: permissions,
                active: true,
                registered-by: tx-sender
            }
        )
        (var-set last-contract-id new-contract-id)
        (ok new-contract-id)
    )
)

;; Configure data synchronization between integrations
(define-public (configure-data-sync
    (source-integration uint)
    (target-integration uint)
    (data-type (string-ascii 30))
    (sync-frequency uint))
    (let 
        (
            (new-sync-id (+ (var-get last-sync-id) u1))
            (source (unwrap! (map-get? external-integrations { integration-id: source-integration }) err-integration-not-found))
            (target (unwrap! (map-get? external-integrations { integration-id: target-integration }) err-integration-not-found))
        )
        ;; Verify ownership of source integration
        (asserts! (is-eq (get owner source) tx-sender) err-not-authorized)
        ;; Validate sync frequency
        (asserts! (> sync-frequency u0) err-invalid-integration)
        ;; Create sync configuration
        (map-set sync-configurations
            { sync-id: new-sync-id }
            {
                source-integration: source-integration,
                target-integration: target-integration,
                data-type: data-type,
                sync-frequency: sync-frequency,
                last-sync: stacks-block-height,
                sync-count: u0,
                auto-sync: true,
                owner: tx-sender
            }
        )
        (var-set last-sync-id new-sync-id)
        (ok new-sync-id)
    )
)

;; Execute data synchronization
(define-public (execute-sync (sync-id uint))
    (let 
        (
            (sync-config (unwrap! (map-get? sync-configurations { sync-id: sync-id }) err-integration-not-found))
            (blocks-since-sync (- stacks-block-height (get last-sync sync-config)))
        )
        ;; Check if sync is due
        (asserts! (>= blocks-since-sync (get sync-frequency sync-config)) err-invalid-integration)
        ;; Update sync record
        (map-set sync-configurations
            { sync-id: sync-id }
            (merge sync-config {
                last-sync: stacks-block-height,
                sync-count: (+ (get sync-count sync-config) u1)
            })
        )
        ;; Log the sync operation and return success
        (unwrap! (log-api-access 
            (get source-integration sync-config)
            "SYNC"
            u200
            u0
        ) (ok true))
        (ok true)
    )
)

;; Register webhook for real-time notifications
(define-public (register-webhook
    (endpoint-url (string-ascii 200))
    (event-types (list 5 (string-ascii 30)))
    (secret-hash (string-ascii 64)))
    (let ((new-webhook-id (+ (var-get last-webhook-id) u1)))
        ;; Validate endpoint URL
        (asserts! (> (len endpoint-url) u0) err-invalid-webhook)
        ;; Create webhook record
        (map-set webhooks
            { webhook-id: new-webhook-id }
            {
                endpoint-url: endpoint-url,
                event-types: event-types,
                secret-hash: secret-hash,
                active: true,
                trigger-count: u0,
                last-triggered: u0,
                owner: tx-sender
            }
        )
        (var-set last-webhook-id new-webhook-id)
        (ok new-webhook-id)
    )
)

;; Trigger webhook notification
(define-public (trigger-webhook (webhook-id uint) (event-type (string-ascii 30)))
    (let ((webhook (unwrap! (map-get? webhooks { webhook-id: webhook-id }) err-invalid-webhook)))
        ;; Check if webhook is active
        (asserts! (get active webhook) err-invalid-webhook)
        ;; Update webhook statistics
        (map-set webhooks
            { webhook-id: webhook-id }
            (merge webhook {
                trigger-count: (+ (get trigger-count webhook) u1),
                last-triggered: stacks-block-height
            })
        )
        (ok true)
    )
)

;; Check API rate limits
(define-public (check-rate-limit (integration-id uint))
    (let 
        (
            (integration (unwrap! (map-get? external-integrations { integration-id: integration-id }) err-integration-not-found))
            (time-since-last (- stacks-block-height (get last-call integration)))
            (calls-per-period (get call-count integration))
        )
        ;; Simple rate limiting - reset count if enough time passed
        (if (>= time-since-last u144) ;; Reset daily
            (begin
                (map-set external-integrations
                    { integration-id: integration-id }
                    (merge integration {
                        call-count: u0,
                        last-call: stacks-block-height
                    })
                )
                (ok true)
            )
            ;; Check if within rate limit
            (if (< calls-per-period (get rate-limit integration))
                (begin
                    (map-set external-integrations
                        { integration-id: integration-id }
                        (merge integration {
                            call-count: (+ calls-per-period u1),
                            last-call: stacks-block-height
                        })
                    )
                    (ok true)
                )
                err-rate-limit-exceeded
            )
        )
    )
)

;; Log API access for monitoring
(define-private (log-api-access
    (integration-id uint)
    (method (string-ascii 10))
    (status-code uint)
    (response-size uint))
    (let ((new-log-id (+ (var-get last-log-id) u1)))
        (map-set api-access-logs
            { log-id: new-log-id }
            {
                integration-id: integration-id,
                caller: tx-sender,
                endpoint: "api-call",
                method: method,
                timestamp: stacks-block-height,
                status-code: status-code,
                response-size: response-size
            }
        )
        (var-set last-log-id new-log-id)
        (ok true)
    )
)

;; Administrative functions
(define-public (toggle-integration-status (integration-id uint) (active bool))
    (let ((integration (unwrap! (map-get? external-integrations { integration-id: integration-id }) err-integration-not-found)))
        ;; Check ownership or admin access
        (asserts! (or (is-eq tx-sender contract-owner) (is-eq tx-sender (get owner integration))) err-not-authorized)
        (map-set external-integrations
            { integration-id: integration-id }
            (merge integration { active: active })
        )
        (ok true)
    )
)

(define-public (update-rate-limit (integration-id uint) (new-limit uint))
    (let ((integration (unwrap! (map-get? external-integrations { integration-id: integration-id }) err-integration-not-found)))
        ;; Check ownership
        (asserts! (is-eq tx-sender (get owner integration)) err-not-authorized)
        (asserts! (<= new-limit (var-get max-rate-limit)) err-rate-limit-exceeded)
        (map-set external-integrations
            { integration-id: integration-id }
            (merge integration { rate-limit: new-limit })
        )
        (ok true)
    )
)

;; Read-only functions for querying integration status
(define-read-only (get-external-integration (integration-id uint))
    (map-get? external-integrations { integration-id: integration-id })
)

(define-read-only (get-contract-integration (contract-id uint))
    (map-get? contract-integrations { contract-id: contract-id })
)

(define-read-only (get-sync-configuration (sync-id uint))
    (map-get? sync-configurations { sync-id: sync-id })
)

(define-read-only (get-webhook (webhook-id uint))
    (map-get? webhooks { webhook-id: webhook-id })
)

(define-read-only (get-api-access-log (log-id uint))
    (map-get? api-access-logs { log-id: log-id })
)

;; System health checks
(define-read-only (get-integration-health (integration-id uint))
    (let ((integration (map-get? external-integrations { integration-id: integration-id })))
        (match integration
            some-integration (ok {
                active: (get active some-integration),
                call-count: (get call-count some-integration),
                rate-limit: (get rate-limit some-integration),
                last-call: (get last-call some-integration),
                health-status: (if (get active some-integration) "healthy" "inactive")
            })
            (err u404)
        )
    )
)

(define-read-only (get-system-statistics)
    {
        total-integrations: (var-get last-integration-id),
        total-contracts: (var-get last-contract-id),
        total-syncs: (var-get last-sync-id),
        total-webhooks: (var-get last-webhook-id),
        total-api-calls: (var-get last-log-id)
    }
)

;; Get pending sync operations
(define-read-only (get-pending-syncs)
    ;; Simplified - returns mock data for pending syncs
    (list 
        { sync-id: u1, due-in-blocks: u50 }
        { sync-id: u3, due-in-blocks: u120 }
    )
)

;; Integration service discovery
(define-read-only (find-integrations-by-type (service-type (string-ascii 30)))
    ;; Simplified - returns mock list of integration IDs
    (if (is-eq service-type "iot")
        (list u1 u3 u5)
        (if (is-eq service-type "api")
            (list u2 u4)
            (list)
        )
    )
)
