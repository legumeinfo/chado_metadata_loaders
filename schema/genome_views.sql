SELECT distinct cp.nid AS project_nid, p.project_id AS project_id, 
       p.name AS project, pp.value AS project_description,
       fpp.value AS funding, cpp.value AS consortium,
       cupp.value AS consortium_URL, bpdx.accession AS bioproject,
       bpdx.db_id AS bioproject_db, cs.nid AS stock_nid, 
       s.stock_id AS stock_id , s.name AS stock_name, 
       sdpp.value AS sample_description,
       bsdx.accession AS biosample,
       bsdx.db_id AS biosample_db,
       p_a.nid AS analysis_nid, p_a.analysis_id AS analysis_id, 
       p_a.name AS assembly_name, p_a.program AS program,
       e.nd_experiment_id, pubdx.accession AS doi, pmdx.accession AS pmid
  FROM project p
    INNER JOIN projectprop pp 
      ON pp.project_id=p.project_id
         AND pp.type_id=(SELECT cvterm_id FROM cvterm 
                         WHERE name='project_description'
                               AND cv_id=(SELECT cv_id FROM cv 
                                          WHERE name='genbank'))
    INNER JOIN
        (SELECT ca.nid, pa.project_id, a.analysis_id, a.name, a.program
         FROM project_analysis pa
           INNER JOIN analysis a ON a.analysis_id=pa.analysis_id
           INNER JOIN analysisprop ap ON ap.analysis_id=a.analysis_id
           INNER JOIN cvterm apt ON apt.cvterm_id=ap.type_id
           LEFT JOIN public.chado_analysis ca ON ca.analysis_id=a.analysis_id
         WHERE ap.value='Genome assembly' AND apt.name='analysis_type'
        ) p_a ON p_a.project_id=p.project_id
    INNER JOIN nd_experiment_project ep ON ep.project_id=p.project_id
    INNER JOIN nd_experiment e ON e.nd_experiment_id=ep.nd_experiment_id
    INNER JOIN nd_experiment_stock es ON es.nd_experiment_id=e.nd_experiment_id
    INNER JOIN stock s ON s.stock_id=es.stock_id

    LEFT JOIN public.chado_project cp ON cp.project_id=p.project_id
    LEFT JOIN public.chado_stock cs ON cs.stock_id=s.stock_id
    
    -- funding
    LEFT JOIN projectprop fpp 
      ON fpp.project_id=p.project_id
         AND fpp.type_id=(SELECT cvterm_id FROM cvterm 
                          WHERE name='funding' 
                                AND cv_id=(SELECT cv_id FROM cv 
                                           WHERE name='genbank'))
    -- consortium
    LEFT JOIN projectprop cpp 
      ON cpp.project_id=p.project_id
         AND cpp.type_id=(SELECT cvterm_id FROM cvterm 
                          WHERE name='consortium' 
                                AND cv_id=(SELECT cv_id FROM cv 
                                           WHERE name='genbank'))
    LEFT JOIN projectprop cupp 
      ON cupp.project_id=p.project_id
         AND cupp.type_id=(SELECT cvterm_id FROM cvterm 
                           WHERE name='consortium_URL' 
                                 AND cv_id=(SELECT cv_id FROM cv 
                                            WHERE name='genbank'))
     -- BioProject
     LEFT JOIN 
       (SELECT project_id, pdx.accession, db.db_id FROM project_dbxref pd
          INNER JOIN dbxref pdx ON pdx.dbxref_id=pd.dbxref_id
          INNER join db ON db.db_id=pdx.db_id
        WHERE db.name='GenBank:BioProject'
       ) bpdx ON bpdx.project_id=p.project_id
     -- BioSample
     LEFT JOIN 
       (SELECT nd_experiment_id, edx.accession, db.db_id 
        FROM nd_experiment_dbxref ed
          INNER JOIN dbxref edx ON edx.dbxref_id=ed.dbxref_id
          INNER join db ON db.db_id=edx.db_id
        WHERE db.name='GenBank:BioSample'
       ) bsdx ON bsdx.nd_experiment_id=e.nd_experiment_id
    -- Sample description
    LEFT JOIN stockprop sdpp 
      ON sdpp.stock_id=s.stock_id
         AND sdpp.type_id=(SELECT cvterm_id FROM cvterm 
                           WHERE name='subject_description' 
                                AND cv_id=(SELECT cv_id FROM cv 
                                           WHERE name='SEQmeta'))
    -- Publication
    LEFT JOIN 
       (SELECT project_id, pdx.accession, db.db_id FROM project_dbxref pd
          INNER JOIN dbxref pdx ON pdx.dbxref_id=pd.dbxref_id
          INNER join db ON db.db_id=pdx.db_id
        WHERE db.name='DOI'
       ) pubdx ON pubdx.project_id=p.project_id
    LEFT JOIN 
       (SELECT project_id, pdx.accession, db.db_id FROM project_dbxref pd
          INNER JOIN dbxref pdx ON pdx.dbxref_id=pd.dbxref_id
          INNER join db ON db.db_id=pdx.db_id
        WHERE db.name='PMID'
       ) pmdx ON pmdx .project_id=p.project_id
    




