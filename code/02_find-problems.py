# --------------------------------------------------------
# Libraries
# --------------------------------------------------------

# Filepaths
from pyprojroot.here import here

# Logging
from datetime import datetime
import logging

# Data formatting
import polars as pl

# NLP
import spacy
spacy.prefer_gpu()

import medspacy
from medspacy.ner import TargetRule


# --------------------------------------------------------
# Logging
# --------------------------------------------------------
logging.basicConfig(filename=here('code/log/temp/02_find-problems.log'),
                    filemode='w',
                    level=logging.INFO,
                    encoding='utf-8')

logger = logging.getLogger(__name__)


# --------------------------------------------------------
# Helpers
# --------------------------------------------------------
# Create medspacy pipeline
def init_pipeline():
    nlp = medspacy.load(medspacy_enable=["medspacy_pyrush", "medspacy_target_matcher"])
    # Targets (entities in the report)    
    target_matcher = nlp.get_pipe('medspacy_target_matcher')
    target_rules = TargetRule.from_json(here('code/02-help_medspacy-targets.json'))
    target_matcher.add(target_rules)
    nlp.batch_size = 16
    return nlp

def literal(ent):
    return ent._.target_rule.literal.lower()

def empty_df(study_id):
    df = pl.DataFrame({"study_id":study_id,
                       "sent_id":-1,
                       "problem":"none_flagged",
                       "sentence":""})
    return df.cast({"study_id": pl.Int32})

# Use {pipeline} to create df of problem sentences from {text} 
# with associated {study_id}
def frame_study(study_id,text,pipeline):    
    if (text is None): return empty_df(study_id)
    # Process file
    # replace "___" with "PII" to improve sentence splitting 
    # this is safe because "PII" never appears in the raw text,
    # so we can swap it back to "___" later.
    text = text.replace("___","PII")
    doc = pipeline(text) 
    if (len(doc.ents) == 0): return empty_df(study_id)
    # List problems
    problems    = [literal(ent) for ent in doc.ents]
    problem_sentences = [ent.sent.text for ent in doc.ents]
    problem_sentences = [sent.strip() for sent in problem_sentences]
    problem_sentences = [sent.replace("PII","___") for sent in problem_sentences]
    # Return df
    df = pl.DataFrame(
        {
            "study_id": int(study_id),
            "sent_id": [ent.sent.start for ent in doc.ents],
            "problem": problems,
            "sentence": problem_sentences
        }
    )
    return df.unique()

def save_sentences(problem_df):
    prob_name = problem_df['problem'][0]
    outfile = here('temp/sentences/'+prob_name+'.csv')
    logger.info("Writing to: "+outfile.as_posix())
    problem_df.write_csv(outfile)
    return None


# --------------------------------------------------------
# Main
# --------------------------------------------------------
def main():
    # Timing
    startTime = datetime.now()     
    # Read report text    
    logger.info("Loading reports...")    
    report_df = pl.read_csv(here('mimic_cxr_reports.csv'),
                            columns = ['study_id', 'body'])
    logger.info("Initializing pipeline...")
    nlp = init_pipeline()
    # Process
    logger.info("Processing studies...")
    sentence_df = [frame_study(s,t,nlp) for s,t in zip(report_df['study_id'],report_df['body'])]
    sentence_df = pl.concat(sentence_df)
    problem_dfs = sentence_df.partition_by('problem')
    # Save
    [save_sentences(prob_df) for prob_df in problem_dfs]        
    # Timing
    runTime = datetime.now() - startTime
    logger.info("Done in " + str(runTime.seconds) + " seconds.")
    return None

if __name__ == "__main__":
    main()
