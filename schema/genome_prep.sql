--------------------------------------------------------------------------------
-- custom tables
--------------------------------------------------------------------------------
-- create from legume_organism/scriptlets/analysis_dbxref_desc.txt
--create table analysis_dbxref (
--  analysis_dbxref_id bigserial not null,
--  analysis_id bigint not null,
--  dbxref_id bigint not null,
--  primary key (analysis_dbxref_id),
--  is_current boolean not null default 'true',
--  foreign key (analysis_id) references analysis (analysis_id) on delete cascade INITIALLY DEFERRED,
--  foreign key (dbxref_id) references dbxref (dbxref_id) on delete cascade INITIALLY DEFERRED,
--  constraint analysis_dbxref_c1 unique (analysis_id,dbxref_id)
--);
--create index analysis_dbxref_idx1 on analysis_dbxref (analysis_id);
--create index analysis_dbxref_idx2 on analysis_dbxref (dbxref_id);

-- Create from legume_organism/scriptlets/project_analysis_desc.txt
--CREATE TABLE project_analysis (
--  project_analysis_id SERIAL NOT NULL,
--    PRIMARY KEY (project_analysis_id),
--  project_id INT NOT NULL,
--    FOREIGN KEY (project_id) REFERENCES project (project_id),
--  analysis_id INT NOT NULL,
--    FOREIGN KEY (analysis_id) REFERENCES analysis (analysis_id),
--  CONSTRAINT project_analysis_c1 UNIQUE(project_id, analysis_id)
--);

-- Create from legume_organism/scriptlets/project_dbxref_desc.txt
--CREATE TABLE project_dbxref (
--   project_dbxref_id SERIAL NOT NULL,
--     PRIMARY KEY (project_dbxref_id),
--   project_id INT NOT NULL,
--     FOREIGN KEY (project_id) REFERENCES project (project_id) ON DELETE CASCADE INITIALLY DEFERRED,
--   dbxref_id int not null,
--     FOREIGN KEY (dbxref_id) REFERENCES dbxref (dbxref_id) ON DELETE CASCADE INITIALLY DEFERRED,
--   is_current BOOLEAN NOT NULL DEFAULT 'true',
--   
--   CONSTRAINT project_dbxref_c1 UNIQUE (project_id, dbxref_id)
--);
--  CREATE INDEX project_dbxref_idx1 ON project_dbxref (project_id);
--  CREATE INDEX project_dbxref_idx2 ON project_dbxref (dbxref_id);
--  
--  COMMENT ON TABLE project_dbxref IS 'project_dbxref links a project to dbxrefs.';
--  COMMENT ON COLUMN project_dbxref.is_current IS 'The is_current boolean indicates whether the linked dbxref is the current -official- dbxref for the linked project.';

--------------------------------------------------------------------------------
-- prerequisite data
--------------------------------------------------------------------------------
INSERT INTO db
  (name, description, urlprefix, url)
VALUES
  ('GenBank:BioProject', 'GenBank BioProject database',
   'http://www.ncbi.nlm.nih.gov/bioproject/',
   'http://www.ncbi.nlm.nih.gov/bioproject'),
  ('GenBank:BioSample', 'GenBank BioSample database',
   'http://www.ncbi.nlm.nih.gov/biosample/',
   'http://www.ncbi.nlm.nih.gov/biosample'),
  ('GenBank:genome', 'GenBank genome database',
   'http://www.ncbi.nlm.nih.gov/genome/',
   'http://www.ncbi.nlm.nih.gov/genome/'),
  ('GenBank:taxonomy', 'GenBank taxonomic database',
   'https://www.ncbi.nlm.nih.gov/taxonomy/',
   'https://www.ncbi.nlm.nih.gov/taxonomy/'),
  ('PI', 'Plant Introduction number',
   '', 'https://npgsweb.ars-grin.gov/gringlobal/search.aspx'),
  ('MaizeGDB Genome Metadata', 'Accession for linking to MaizeGDB genome metadata page',
   '/genome/genome_assembly/', '/genome')
;

UPDATE db
  SET description='NCBI PubMed ID', 
      urlprefix='https://www.ncbi.nlm.nih.gov/pubmed/'
WHERE name='PMID';

INSERT INTO db
  (name, description, urlprefix, url)
VALUES
  ('GenBank:nucleotide', 
   'GenBank nucleotide database',
   'https://www.ncbi.nlm.nih.gov/nuccore/',
   'https://www.ncbi.nlm.nih.gov/nuccore/')
;

INSERT INTO dbxref
  (db_id, accession, description)
VALUES
  ((SELECT db_id FROM db WHERE name='tripal'),
   'accession',
   'A stock which exists as an accession at a stock center or germplasm bank.')
;
INSERT INTO cvterm
  (cv_id, name, definition, dbxref_id)
VALUES
  ((SELECT cv_id FROM cv WHERE name='stock_type'),
  'Accession',
  'A stock which exists as an accession at a stock center or germplasm bank.',
  (SELECT dbxref_id FROM dbxref WHERE accession='accession')
  )
;

INSERT INTO nd_geolocation 
  (description)
VALUES
  ('unknown')
;