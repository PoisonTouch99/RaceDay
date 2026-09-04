/* ============================================================
   RaceDay Database Schema
   SQL Server (SSMS) - creates schema + seeds sample data
   This script matches the ERD in RaceDay_ERD.png exactly.
   ============================================================ */

IF DB_ID('RaceDayDB') IS NULL
BEGIN
    CREATE DATABASE RaceDayDB;
END
GO

USE RaceDayDB;
GO

/* ------------------------------------------------------------
   Order respects foreign key dependencies (children first)
   ------------------------------------------------------------ */
IF OBJECT_ID('dbo.Payments', 'U') IS NOT NULL DROP TABLE dbo.Payments;
IF OBJECT_ID('dbo.Results', 'U') IS NOT NULL DROP TABLE dbo.Results;
IF OBJECT_ID('dbo.Enrolments', 'U') IS NOT NULL DROP TABLE dbo.Enrolments;
IF OBJECT_ID('dbo.Categories', 'U') IS NOT NULL DROP TABLE dbo.Categories;
IF OBJECT_ID('dbo.Events', 'U') IS NOT NULL DROP TABLE dbo.Events;
IF OBJECT_ID('dbo.RefreshTokens', 'U') IS NOT NULL DROP TABLE dbo.RefreshTokens;
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL DROP TABLE dbo.Users;
GO

/* ------------------------------------------------------------
   Users
   ------------------------------------------------------------ */
CREATE TABLE dbo.Users (
    UserId          INT IDENTITY(1,1) PRIMARY KEY,
    FullName        NVARCHAR(100)   NOT NULL,
    Email           NVARCHAR(150)   NOT NULL UNIQUE,
    PasswordHash    NVARCHAR(255)   NOT NULL,
    Role            NVARCHAR(20)    NOT NULL
                        CONSTRAINT CK_Users_Role CHECK (Role IN ('Organiser', 'Participant')),
    Phone           NVARCHAR(20)    NULL,
    CreatedAt       DATETIME        NOT NULL DEFAULT GETDATE()
);
GO

/* ------------------------------------------------------------
   RefreshTokens  (1 User -> M RefreshTokens)
   ------------------------------------------------------------ */
CREATE TABLE dbo.RefreshTokens (
    TokenId         INT IDENTITY(1,1) PRIMARY KEY,
    UserId          INT             NOT NULL,
    Token           NVARCHAR(255)   NOT NULL UNIQUE,
    ExpiresAt       DATETIME        NOT NULL,
    CreatedAt       DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId)
        REFERENCES dbo.Users(UserId) ON DELETE CASCADE
);
GO

/* ------------------------------------------------------------
   Events  (1 Organiser (User) -> M Events)
   ------------------------------------------------------------ */
CREATE TABLE dbo.Events (
    EventId         INT IDENTITY(1,1) PRIMARY KEY,
    OrganiserId     INT             NOT NULL,
    Name            NVARCHAR(150)   NOT NULL,
    Description     NVARCHAR(1000)  NULL,
    EventDate       DATE            NOT NULL,
    Location        NVARCHAR(150)   NOT NULL,
    Status          NVARCHAR(20)    NOT NULL DEFAULT 'Draft'
                        CONSTRAINT CK_Events_Status CHECK (Status IN ('Draft', 'Published', 'Closed')),
    CreatedAt       DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Events_Organiser FOREIGN KEY (OrganiserId)
        REFERENCES dbo.Users(UserId)
);
GO

/* ------------------------------------------------------------
   Categories  (1 Event -> M Categories)
   ------------------------------------------------------------ */
CREATE TABLE dbo.Categories (
    CategoryId      INT IDENTITY(1,1) PRIMARY KEY,
    EventId         INT             NOT NULL,
    Name            NVARCHAR(100)   NOT NULL,
    DistanceKm      DECIMAL(5,2)    NOT NULL,
    MaxParticipants INT             NOT NULL DEFAULT 100,
    EntryFee        DECIMAL(8,2)    NOT NULL DEFAULT 0,
    CONSTRAINT FK_Categories_Events FOREIGN KEY (EventId)
        REFERENCES dbo.Events(EventId) ON DELETE CASCADE
);
GO

/* ------------------------------------------------------------
   Enrolments  (M-M between Participant (User) and Category,
   resolved as a junction table with its own attributes)
   ------------------------------------------------------------ */
CREATE TABLE dbo.Enrolments (
    EnrolmentId     INT IDENTITY(1,1) PRIMARY KEY,
    ParticipantId   INT             NOT NULL,
    CategoryId      INT             NOT NULL,
    BibNumber       NVARCHAR(10)    NOT NULL UNIQUE,
    EnrolmentDate   DATETIME        NOT NULL DEFAULT GETDATE(),
    Status          NVARCHAR(20)    NOT NULL DEFAULT 'Pending'
                        CONSTRAINT CK_Enrolments_Status CHECK (Status IN ('Pending', 'Confirmed', 'Cancelled')),
    CONSTRAINT FK_Enrolments_Users FOREIGN KEY (ParticipantId)
        REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_Enrolments_Categories FOREIGN KEY (CategoryId)
        REFERENCES dbo.Categories(CategoryId),
    CONSTRAINT UQ_Enrolments_Participant_Category UNIQUE (ParticipantId, CategoryId)
);
GO

/* ------------------------------------------------------------
   Results  (1-to-1 with Enrolments)
   ------------------------------------------------------------ */
CREATE TABLE dbo.Results (
    ResultId        INT IDENTITY(1,1) PRIMARY KEY,
    EnrolmentId     INT             NOT NULL UNIQUE,
    FinishTime      TIME            NULL,
    Position        INT             NULL,
    Status          NVARCHAR(20)    NOT NULL DEFAULT 'Finished'
                        CONSTRAINT CK_Results_Status CHECK (Status IN ('Finished', 'DNF', 'DSQ')),
    RecordedAt      DATETIME        NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Results_Enrolments FOREIGN KEY (EnrolmentId)
        REFERENCES dbo.Enrolments(EnrolmentId) ON DELETE CASCADE
);
GO

/* ------------------------------------------------------------
   Payments  (1-to-1 with Enrolments)
   ------------------------------------------------------------ */
CREATE TABLE dbo.Payments (
    PaymentId       INT IDENTITY(1,1) PRIMARY KEY,
    EnrolmentId     INT             NOT NULL UNIQUE,
    Amount          DECIMAL(8,2)    NOT NULL,
    PaymentDate     DATETIME        NOT NULL DEFAULT GETDATE(),
    PaymentStatus   NVARCHAR(20)    NOT NULL DEFAULT 'Pending'
                        CONSTRAINT CK_Payments_Status CHECK (PaymentStatus IN ('Pending', 'Paid', 'Refunded')),
    CONSTRAINT FK_Payments_Enrolments FOREIGN KEY (EnrolmentId)
        REFERENCES dbo.Enrolments(EnrolmentId) ON DELETE CASCADE
);
GO

/* ============================================================
   SEED DATA
   2 Organisers, 2 Participants (min. required), 3 Events,
   categories for each event, and sample enrolments.
   ============================================================ */

-- Organisers
INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role, Phone) VALUES
('Sarah Nkosi',   'sarah.nkosi@raceday.co.za',   'HASH_PLACEHOLDER_1', 'Organiser', '0821234567'),
('David Botha',   'david.botha@raceday.co.za',   'HASH_PLACEHOLDER_2', 'Organiser', '0839876543');

-- Participants
INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role, Phone) VALUES
('Thabo Mokoena',  'thabo.mokoena@example.com',  'HASH_PLACEHOLDER_3', 'Participant', '0731112222'),
('Emma van Wyk',   'emma.vanwyk@example.com',    'HASH_PLACEHOLDER_4', 'Participant', '0723334444');

-- Events (EventId 1 & 2 -> Organiser 1 "Sarah"; EventId 3 -> Organiser 2 "David")
INSERT INTO dbo.Events (OrganiserId, Name, Description, EventDate, Location, Status) VALUES
(1, 'Johannesburg City Run',   'Annual road race through the Johannesburg CBD.',        '2026-10-10', 'Johannesburg, Gauteng', 'Published'),
(1, 'Sandton Fun Run',         'A family-friendly fun run in Sandton.',                  '2026-11-15', 'Sandton, Gauteng',      'Published'),
(2, 'Cape Town Coastal Marathon', 'Scenic marathon along the Cape Town coastline.',      '2026-09-20', 'Cape Town, Western Cape', 'Published');

-- Categories (spread across each of the 3 events)
INSERT INTO dbo.Categories (EventId, Name, DistanceKm, MaxParticipants, EntryFee) VALUES
(1, '5km Fun Run',    5.00,  200, 100.00),
(1, '10km Road Race', 10.00, 150, 150.00),
(2, '5km Family Run', 5.00,  300, 80.00),
(3, 'Half Marathon',  21.10, 500, 250.00),
(3, 'Full Marathon',  42.20, 500, 350.00);

-- Enrolments (Thabo & Emma enrol in a couple of categories each)
INSERT INTO dbo.Enrolments (ParticipantId, CategoryId, BibNumber, Status) VALUES
(3, 1, 'BIB001', 'Confirmed'),  -- Thabo -> 5km Fun Run (Jhb City Run)
(3, 4, 'BIB002', 'Confirmed'),  -- Thabo -> Half Marathon (Cape Town)
(4, 2, 'BIB003', 'Confirmed'),  -- Emma  -> 10km Road Race (Jhb City Run)
(4, 3, 'BIB004', 'Pending');    -- Emma  -> 5km Family Run (Sandton)

-- Results (one finished result recorded so far)
INSERT INTO dbo.Results (EnrolmentId, FinishTime, Position, Status) VALUES
(1, '00:26:14', 12, 'Finished');

-- Payments (matching the enrolments above)
INSERT INTO dbo.Payments (EnrolmentId, Amount, PaymentStatus) VALUES
(1, 100.00, 'Paid'),
(2, 250.00, 'Paid'),
(3, 150.00, 'Paid'),
(4, 80.00,  'Pending');
GO

/* ------------------------------------------------------------
   Quick sanity check queries (optional - comment out if not needed)
   ------------------------------------------------------------ */
-- SELECT * FROM dbo.Users;
-- SELECT * FROM dbo.Events;
-- SELECT * FROM dbo.Categories;
-- SELECT * FROM dbo.Enrolments;
-- SELECT * FROM dbo.Results;
-- SELECT * FROM dbo.Payments;